import Foundation
import Combine
import SwiftUI

/// Main view model managing shopping list state.
@MainActor
class ShoppingListViewModel: ObservableObject {
    @Published var ingredients: [IngredientItem] = []
    @Published var additionalItems: [AdditionalItem] = []
    @Published var recipes: [ShoppingRecipe] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdated: Date?

    private let api = APIService.shared

    /// Incremented on every local mutation. Used to discard stale fetch
    /// responses that completed after a user mutation — without this, an
    /// in-flight fetch could clobber an optimistic update with pre-mutation
    /// server state.
    private var mutationGeneration: Int = 0

    init() {
        loadFromCache()
    }

    private var currentServerURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? ""
    }

    private func loadFromCache() {
        guard let snapshot = ShoppingListCache.load() else { return }
        let configured = currentServerURL
        guard !configured.isEmpty, snapshot.serverURL == configured else {
            ShoppingListCache.clear()
            return
        }
        ingredients = snapshot.response.ingredients
        additionalItems = snapshot.response.additionalItems
        recipes = snapshot.response.recipes
        lastUpdated = snapshot.fetchedAt
    }

    /// Reset all in-memory + cached state.
    /// Call when the server URL or API key changes (e.g. new config from the iPhone).
    func resetForConfigurationChange() {
        mutationGeneration += 1
        ingredients = []
        additionalItems = []
        recipes = []
        lastUpdated = nil
        error = nil
        ShoppingListCache.clear()
    }

    /// Persist the current in-memory state to disk.
    /// Called after every successful mutation so that a relaunch shows the
    /// latest user-confirmed state, not stale pre-mutation data.
    private func saveCurrentToCache() {
        let response = ShoppingListResponse(
            ingredients: ingredients,
            additionalItems: additionalItems,
            recipes: recipes
        )
        ShoppingListCache.save(response, serverURL: currentServerURL)
        lastUpdated = Date()
    }

    // MARK: - Grouped Data

    /// All items as a flat list (sorted: unchecked first, then checked)
    var allItems: [ShoppingItem] {
        var items: [ShoppingItem] = []
        items.append(contentsOf: ingredients.map { .ingredient($0) })
        items.append(contentsOf: additionalItems.map { .additional($0) })
        return items.sorted { !$0.isOwned && $1.isOwned }
    }

    /// Items grouped by recipe (recipe view)
    var itemsByRecipe: [(recipeName: String, recipeId: String?, items: [ShoppingItem])] {
        var sections: [(recipeName: String, recipeId: String?, items: [ShoppingItem])] = []

        for recipe in recipes {
            let items = recipe.ingredients.map { ShoppingItem.ingredient($0) }
            if !items.isEmpty {
                sections.append((recipeName: recipe.name, recipeId: recipe.id, items: items))
            }
        }

        // Additional items as "Sonstiges" / "Other"
        if !additionalItems.isEmpty {
            sections.append((
                recipeName: String(localized: "Sonstiges"),
                recipeId: nil,
                items: additionalItems.map { .additional($0) }
            ))
        }

        return sections
    }

    // MARK: - Data Fetching

    func fetchShoppingList() async {
        let myGeneration = mutationGeneration
        isLoading = true
        let hadCache = !ingredients.isEmpty || !additionalItems.isEmpty || !recipes.isEmpty
        if !hadCache {
            error = nil
        }
        defer { isLoading = false }

        do {
            let response = try await api.fetchShoppingList()
            // Discard stale responses: the user mutated state while this
            // fetch was in flight, so its body no longer reflects what the
            // user expects to see. Local state is already authoritative;
            // the next fetch will pick up the post-mutation server state.
            guard myGeneration == mutationGeneration else { return }
            ingredients = response.ingredients
            additionalItems = response.additionalItems
            recipes = response.recipes
            lastUpdated = Date()
            error = nil
            ShoppingListCache.save(response, serverURL: currentServerURL)
        } catch {
            // Keep cached data visible; only surface the error message.
            self.error = error.localizedDescription
        }
    }

    // MARK: - Toggle Ownership

    func toggleItem(_ item: ShoppingItem) async {
        mutationGeneration += 1
        switch item {
        case .ingredient(let ingredient):
            // Optimistic update
            if let idx = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                ingredients[idx].isOwned.toggle()
            }
            do {
                _ = try await api.toggleIngredientOwnership(
                    id: ingredient.id,
                    isOwned: !ingredient.isOwned
                )
                saveCurrentToCache()
            } catch {
                // Revert on failure
                if let idx = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                    ingredients[idx].isOwned = ingredient.isOwned
                }
                self.error = error.localizedDescription
            }

        case .additional(let additional):
            if let idx = additionalItems.firstIndex(where: { $0.id == additional.id }) {
                additionalItems[idx].isOwned.toggle()
            }
            do {
                _ = try await api.toggleAdditionalItemOwnership(
                    id: additional.id,
                    isOwned: !additional.isOwned
                )
                saveCurrentToCache()
            } catch {
                if let idx = additionalItems.firstIndex(where: { $0.id == additional.id }) {
                    additionalItems[idx].isOwned = additional.isOwned
                }
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Add Items

    func addItem(name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        mutationGeneration += 1
        do {
            let newItems = try await api.addAdditionalItems(names: [name])
            additionalItems.append(contentsOf: newItems)
            saveCurrentToCache()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Remove Items

    func removeAdditionalItem(id: String) async {
        mutationGeneration += 1
        additionalItems.removeAll { $0.id == id }
        do {
            try await api.removeAdditionalItem(id: id)
            saveCurrentToCache()
        } catch {
            self.error = error.localizedDescription
            await fetchShoppingList() // resync
        }
    }

    func removeRecipeIngredients(recipeId: String) async {
        mutationGeneration += 1
        ingredients.removeAll { $0.recipeId == recipeId }
        recipes.removeAll { $0.id == recipeId }
        do {
            try await api.removeRecipeIngredients(recipeId: recipeId)
            saveCurrentToCache()
        } catch {
            self.error = error.localizedDescription
            await fetchShoppingList()
        }
    }

    func clearShoppingList() async {
        mutationGeneration += 1
        // Snapshot for rollback on failure.
        let prevIngredients = ingredients
        let prevAdditional = additionalItems
        let prevRecipes = recipes

        ingredients = []
        additionalItems = []
        recipes = []

        do {
            try await api.clearShoppingList()
            saveCurrentToCache()
        } catch {
            ingredients = prevIngredients
            additionalItems = prevAdditional
            recipes = prevRecipes
            self.error = error.localizedDescription
            await fetchShoppingList()
        }
    }
}
