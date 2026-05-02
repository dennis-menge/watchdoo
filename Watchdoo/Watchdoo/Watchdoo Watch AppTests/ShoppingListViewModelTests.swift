import XCTest
@testable import Watchdoo_Watch_App

/// Tests for ShoppingListViewModel grouping and computed properties.
final class ShoppingListViewModelTests: XCTestCase {

    private var viewModel: ShoppingListViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        viewModel = ShoppingListViewModel()
    }

    // MARK: - Category Grouping

    @MainActor
    func testItemsByCategoryGrouping() {
        viewModel.ingredients = [
            IngredientItem(id: "i1", name: "Butter", description: "40g Butter",
                          isOwned: false, recipeId: "r1", recipeName: "Kuchen",
                          shoppingCategory: "Milchprodukte"),
            IngredientItem(id: "i2", name: "Zucker", description: "200g Zucker",
                          isOwned: false, recipeId: "r1", recipeName: "Kuchen",
                          shoppingCategory: "Grundnahrungsmittel"),
            IngredientItem(id: "i3", name: "Sahne", description: "100ml Sahne",
                          isOwned: true, recipeId: "r1", recipeName: "Kuchen",
                          shoppingCategory: "Milchprodukte"),
        ]
        viewModel.additionalItems = [
            AdditionalItem(id: "a1", name: "Brot", isOwned: false),
        ]

        let grouped = viewModel.itemsByCategory
        XCTAssertEqual(grouped.count, 3) // Grundnahrungsmittel, Milchprodukte, Sonstiges

        let milch = grouped.first { $0.category == "Milchprodukte" }
        XCTAssertNotNil(milch)
        XCTAssertEqual(milch?.items.count, 2) // Butter + Sahne

        let sonstiges = grouped.first { $0.category == "Sonstiges" }
        XCTAssertNotNil(sonstiges)
        XCTAssertEqual(sonstiges?.items.count, 1) // Brot
    }

    @MainActor
    func testItemsByCategoryEmpty() {
        let grouped = viewModel.itemsByCategory
        XCTAssertTrue(grouped.isEmpty)
    }

    // MARK: - Recipe Grouping

    @MainActor
    func testItemsByRecipeGrouping() {
        viewModel.recipes = [
            ShoppingRecipe(id: "r1", name: "Kuchen", ingredients: []),
            ShoppingRecipe(id: "r2", name: "Suppe", ingredients: []),
        ]
        viewModel.ingredients = [
            IngredientItem(id: "i1", name: "Butter", description: "40g Butter",
                          isOwned: false, recipeId: "r1", recipeName: "Kuchen",
                          shoppingCategory: "Milchprodukte"),
            IngredientItem(id: "i2", name: "Zwiebel", description: "1 Zwiebel",
                          isOwned: false, recipeId: "r2", recipeName: "Suppe",
                          shoppingCategory: "Gemüse"),
        ]
        viewModel.additionalItems = [
            AdditionalItem(id: "a1", name: "Brot", isOwned: false),
        ]

        let grouped = viewModel.itemsByRecipe
        XCTAssertEqual(grouped.count, 3) // Kuchen, Suppe, Sonstiges

        let kuchen = grouped.first { $0.recipeName == "Kuchen" }
        XCTAssertNotNil(kuchen)
        XCTAssertEqual(kuchen?.recipeId, "r1")
        XCTAssertEqual(kuchen?.items.count, 1)

        let sonstiges = grouped.last
        XCTAssertEqual(sonstiges?.recipeName, "Sonstiges")
        XCTAssertNil(sonstiges?.recipeId)
        XCTAssertEqual(sonstiges?.items.count, 1)
    }

    @MainActor
    func testItemsByRecipeNoAdditionalItems() {
        viewModel.recipes = [
            ShoppingRecipe(id: "r1", name: "Kuchen", ingredients: []),
        ]
        viewModel.ingredients = [
            IngredientItem(id: "i1", name: "Butter", description: "40g Butter",
                          isOwned: false, recipeId: "r1", recipeName: "Kuchen",
                          shoppingCategory: nil),
        ]

        let grouped = viewModel.itemsByRecipe
        XCTAssertEqual(grouped.count, 1) // Only Kuchen, no "Sonstiges"
    }

    @MainActor
    func testItemsByRecipeEmpty() {
        let grouped = viewModel.itemsByRecipe
        XCTAssertTrue(grouped.isEmpty)
    }
}
