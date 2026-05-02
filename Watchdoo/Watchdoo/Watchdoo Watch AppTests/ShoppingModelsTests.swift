import XCTest
@testable import Watchdoo_Watch_App

/// Tests for ShoppingModels data types and computed properties.
final class ShoppingModelsTests: XCTestCase {

    // MARK: - IngredientItem

    func testIngredientItemDecoding() throws {
        let json = """
        {
            "id": "ing-1",
            "name": "Butter",
            "description": "40g Butter",
            "is_owned": false,
            "recipe_id": "r123",
            "recipe_name": "Kuchen",
            "shopping_category": "Milchprodukte"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(IngredientItem.self, from: json)
        XCTAssertEqual(item.id, "ing-1")
        XCTAssertEqual(item.name, "Butter")
        XCTAssertEqual(item.description, "40g Butter")
        XCTAssertFalse(item.isOwned)
        XCTAssertEqual(item.recipeId, "r123")
        XCTAssertEqual(item.recipeName, "Kuchen")
        XCTAssertEqual(item.shoppingCategory, "Milchprodukte")
    }

    func testIngredientItemDecodingWithNulls() throws {
        let json = """
        {
            "id": "ing-2",
            "name": "Zucker",
            "description": "200g Zucker",
            "is_owned": true,
            "recipe_id": null,
            "recipe_name": null,
            "shopping_category": null
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(IngredientItem.self, from: json)
        XCTAssertTrue(item.isOwned)
        XCTAssertNil(item.recipeId)
        XCTAssertNil(item.recipeName)
        XCTAssertNil(item.shoppingCategory)
    }

    // MARK: - AdditionalItem

    func testAdditionalItemDecoding() throws {
        let json = """
        {"id": "add-1", "name": "Milch", "is_owned": false}
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(AdditionalItem.self, from: json)
        XCTAssertEqual(item.id, "add-1")
        XCTAssertEqual(item.name, "Milch")
        XCTAssertFalse(item.isOwned)
    }

    // MARK: - ShoppingListResponse

    func testShoppingListResponseDecoding() throws {
        let json = """
        {
            "ingredients": [
                {"id": "i1", "name": "Butter", "description": "40g", "is_owned": false}
            ],
            "additional_items": [
                {"id": "a1", "name": "Milch", "is_owned": true}
            ],
            "recipes": [
                {
                    "id": "r1",
                    "name": "Kuchen",
                    "ingredients": [
                        {"id": "i1", "name": "Butter", "description": "40g", "is_owned": false}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ShoppingListResponse.self, from: json)
        XCTAssertEqual(response.ingredients.count, 1)
        XCTAssertEqual(response.additionalItems.count, 1)
        XCTAssertEqual(response.recipes.count, 1)
        XCTAssertEqual(response.recipes[0].name, "Kuchen")
    }

    // MARK: - ShoppingItem Enum

    func testShoppingItemIngredientProperties() {
        let ingredient = IngredientItem(
            id: "i1", name: "Butter", description: "40g Butter",
            isOwned: false, recipeId: "r1", recipeName: "Kuchen",
            shoppingCategory: "Milchprodukte"
        )
        let item = ShoppingItem.ingredient(ingredient)

        XCTAssertEqual(item.id, "ing-i1")
        XCTAssertEqual(item.displayName, "40g Butter")
        XCTAssertFalse(item.isOwned)
        XCTAssertEqual(item.recipeName, "Kuchen")
        XCTAssertEqual(item.recipeId, "r1")
        XCTAssertEqual(item.category, "Milchprodukte")
        XCTAssertFalse(item.isAdditional)
    }

    func testShoppingItemAdditionalProperties() {
        let additional = AdditionalItem(id: "a1", name: "Milch", isOwned: true)
        let item = ShoppingItem.additional(additional)

        XCTAssertEqual(item.id, "add-a1")
        XCTAssertEqual(item.displayName, "Milch")
        XCTAssertTrue(item.isOwned)
        XCTAssertNil(item.recipeName)
        XCTAssertNil(item.recipeId)
        XCTAssertEqual(item.category, "Sonstiges")
        XCTAssertTrue(item.isAdditional)
    }

    func testShoppingItemFallbackCategory() {
        let ingredient = IngredientItem(
            id: "i2", name: "Test", description: "",
            isOwned: false, recipeId: nil, recipeName: nil,
            shoppingCategory: nil
        )
        let item = ShoppingItem.ingredient(ingredient)
        XCTAssertEqual(item.category, "Sonstiges")
    }

    func testShoppingItemDisplayNameFallback() {
        let ingredient = IngredientItem(
            id: "i3", name: "Salz", description: "",
            isOwned: false, recipeId: nil, recipeName: nil,
            shoppingCategory: nil
        )
        let item = ShoppingItem.ingredient(ingredient)
        XCTAssertEqual(item.displayName, "Salz") // falls back to name when description is empty
    }
}
