import SwiftUI

/// Main shopping list view with toolbar toggle between Zutaten/Gerichte.
struct ShoppingListView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var viewMode: ViewMode = .category
    @State private var showAddItem = false
    @State private var showClearConfirmation = false

    enum ViewMode {
        case category
        case recipe

        var title: LocalizedStringKey {
            switch self {
            case .category: return "Zutaten"
            case .recipe: return "Gerichte"
            }
        }

        var toggleIcon: String {
            switch self {
            case .category: return "fork.knife"
            case .recipe: return "tag"
            }
        }

        var toggled: ViewMode {
            self == .category ? .recipe : .category
        }
    }

    private var hasAnyItems: Bool {
        !viewModel.ingredients.isEmpty || !viewModel.additionalItems.isEmpty
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !hasAnyItems {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, !hasAnyItems {
                ErrorView(message: error) {
                    Task { await viewModel.fetchShoppingList() }
                }
            } else if !hasAnyItems {
                ContentUnavailableView {
                    Label("Liste leer", systemImage: "cart")
                } description: {
                    Text("Tippe auf +, um Items hinzuzufügen.")
                }
            } else {
                switch viewMode {
                case .category:
                    CategoryListView(viewModel: viewModel)
                case .recipe:
                    RecipeListView(viewModel: viewModel)
                }
            }
        }
        .navigationTitle(viewMode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task { await viewModel.fetchShoppingList() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.error != nil {
                        Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Aktualisieren")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { viewMode = viewMode.toggled }
                } label: {
                    Image(systemName: viewMode.toggleIcon)
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .disabled(!hasAnyItems)
                Spacer()
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
                .tint(Color("AccentColor"))
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Liste komplett löschen?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Alles löschen", role: .destructive) {
                Task { await viewModel.clearShoppingList() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Zutaten, Rezepte und eigenen Items werden aus der Cookidoo-Einkaufsliste entfernt.")
        }
        .task {
            await viewModel.fetchShoppingList()
        }
    }
}

// MARK: - Category View (flat list grouped by shopping category)

struct CategoryListView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var recipeToDelete: (name: String, id: String)?

    var body: some View {
        List {
            ForEach(viewModel.allItems) { item in
                ItemRowView(item: item) {
                    Task { await viewModel.toggleItem(item) }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteButton(for: item)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.fetchShoppingList()
        }
        .confirmationDialog(
            "Rezept entfernen?",
            isPresented: Binding(
                get: { recipeToDelete != nil },
                set: { if !$0 { recipeToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let recipe = recipeToDelete {
                Button("Alle Zutaten von \"\(recipe.name)\" entfernen", role: .destructive) {
                    Task { await viewModel.removeRecipeIngredients(recipeId: recipe.id) }
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func deleteButton(for item: ShoppingItem) -> some View {
        switch item {
        case .additional(let additional):
            Button(role: .destructive) {
                Task { await viewModel.removeAdditionalItem(id: additional.id) }
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        case .ingredient(let ingredient):
            if let recipeId = ingredient.recipeId, let recipeName = ingredient.recipeName {
                Button(role: .destructive) {
                    recipeToDelete = (name: recipeName, id: recipeId)
                } label: {
                    Label("Rezept entfernen", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Recipe View (grouped by recipe)

struct RecipeListView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var recipeToDelete: (name: String, id: String)?

    var body: some View {
        List {
            ForEach(viewModel.itemsByRecipe, id: \.recipeName) { section in
                Section(header: recipeSectionHeader(section)) {
                    ForEach(section.items) { item in
                        ItemRowView(item: item) {
                            Task { await viewModel.toggleItem(item) }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.fetchShoppingList()
        }
        .confirmationDialog(
            "Rezept entfernen?",
            isPresented: Binding(
                get: { recipeToDelete != nil },
                set: { if !$0 { recipeToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let recipe = recipeToDelete {
                Button("Alle Zutaten von \"\(recipe.name)\" entfernen", role: .destructive) {
                    Task { await viewModel.removeRecipeIngredients(recipeId: recipe.id) }
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func recipeSectionHeader(_ section: (recipeName: String, recipeId: String?, items: [ShoppingItem])) -> some View {
        HStack {
            if section.recipeId != nil {
                Image(systemName: "fork.knife")
                    .font(.caption2)
            }
            Text(section.recipeName.uppercased())
                .font(.caption2)
            Spacer()
            if let recipeId = section.recipeId {
                Button {
                    recipeToDelete = (name: section.recipeName, id: recipeId)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen", action: retry)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
