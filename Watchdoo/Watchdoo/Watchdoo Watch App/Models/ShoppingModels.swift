import Foundation

/// A single ingredient item from a recipe on the shopping list.
struct IngredientItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    var isOwned: Bool
    let recipeId: String?
    let recipeName: String?
    let shoppingCategory: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isOwned = "is_owned"
        case recipeId = "recipe_id"
        case recipeName = "recipe_name"
        case shoppingCategory = "shopping_category"
    }
}

/// A manually added item on the shopping list.
struct AdditionalItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var isOwned: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case isOwned = "is_owned"
    }
}

/// A recipe contributing ingredients to the shopping list.
struct ShoppingRecipe: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let ingredients: [IngredientItem]
}

/// Complete shopping list response from the backend.
struct ShoppingListResponse: Codable {
    let ingredients: [IngredientItem]
    let additionalItems: [AdditionalItem]
    let recipes: [ShoppingRecipe]

    enum CodingKeys: String, CodingKey {
        case ingredients
        case additionalItems = "additional_items"
        case recipes
    }
}

/// Represents any item on the list (ingredient or additional) for unified display.
enum ShoppingItem: Identifiable, Hashable {
    case ingredient(IngredientItem)
    case additional(AdditionalItem)

    var id: String {
        switch self {
        case .ingredient(let item): return "ing-\(item.id)"
        case .additional(let item): return "add-\(item.id)"
        }
    }

    var displayName: String {
        switch self {
        case .ingredient(let item):
            if item.description.isEmpty {
                return item.name
            }
            return "\(item.description) \(item.name)"
        case .additional(let item): return item.name
        }
    }

    var isOwned: Bool {
        switch self {
        case .ingredient(let item): return item.isOwned
        case .additional(let item): return item.isOwned
        }
    }

    var recipeName: String? {
        switch self {
        case .ingredient(let item): return item.recipeName
        case .additional: return nil
        }
    }

    var recipeId: String? {
        switch self {
        case .ingredient(let item): return item.recipeId
        case .additional: return nil
        }
    }

    var category: String {
        switch self {
        case .ingredient(let item): return item.shoppingCategory ?? "Sonstiges"
        case .additional: return "Sonstiges"
        }
    }

    var isAdditional: Bool {
        if case .additional = self { return true }
        return false
    }
}
