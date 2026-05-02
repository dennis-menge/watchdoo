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

    private let api = APIService.shared

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
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await api.fetchShoppingList()
            ingredients = response.ingredients
            additionalItems = response.additionalItems
            recipes = response.recipes
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Toggle Ownership

    func toggleItem(_ item: ShoppingItem) async {
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
        do {
            let newItems = try await api.addAdditionalItems(names: [name])
            additionalItems.append(contentsOf: newItems)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Remove Items

    func removeAdditionalItem(id: String) async {
        additionalItems.removeAll { $0.id == id }
        do {
            try await api.removeAdditionalItem(id: id)
        } catch {
            self.error = error.localizedDescription
            await fetchShoppingList() // resync
        }
    }

    func removeRecipeIngredients(recipeId: String) async {
        ingredients.removeAll { $0.recipeId == recipeId }
        recipes.removeAll { $0.id == recipeId }
        do {
            try await api.removeRecipeIngredients(recipeId: recipeId)
        } catch {
            self.error = error.localizedDescription
            await fetchShoppingList()
        }
    }
}
