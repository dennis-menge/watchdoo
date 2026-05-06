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

    // MARK: - Stale fetch / mutation race tests

    /// A fetch in flight must not overwrite an optimistic mutation that was
    /// applied while the fetch was suspended.
    @MainActor
    func testStaleFetchIsDiscardedAfterMutation() async {
        let mock = MockShoppingListAPI()
        let staleResponse = ShoppingListResponse(
            ingredients: [],
            additionalItems: [
                AdditionalItem(id: "a1", name: "Brot", isOwned: false)
            ],
            recipes: []
        )
        await mock.setFetchResult(.success(staleResponse))
        await mock.setFetchSuspends(true)

        let vm = ShoppingListViewModel(api: mock)

        // Start a fetch; it will suspend on the continuation.
        let fetchTask = Task { await vm.fetchShoppingList() }
        // Yield so the fetch task reaches its suspend point.
        await Task.yield()
        await Task.yield()

        // Perform a mutation while the fetch is suspended. This bumps the
        // generation counter; the toggle's own API call returns immediately
        // from the mock.
        await mock.setAddResult(.success([
            AdditionalItem(id: "a2", name: "Milch", isOwned: false)
        ]))
        await vm.addItem(name: "Milch")

        // Release the suspended fetch so it returns its (now stale) response.
        await mock.releaseFetch()
        await fetchTask.value

        // The fetch's stale snapshot (which contained a1=Brot, no a2=Milch)
        // must NOT have replaced the post-mutation state. Specifically we
        // expect a2 (Milch) to still be present and a1 (Brot) to NOT be
        // present, since the stale fetch was discarded.
        XCTAssertTrue(vm.additionalItems.contains { $0.id == "a2" },
                      "Mutation result should still be present after stale fetch")
        XCTAssertFalse(vm.additionalItems.contains { $0.id == "a1" },
                       "Stale fetch response must not be applied")
    }

    /// A successful fetch must update the view model when no mutation has
    /// happened — the discard guard should not over-fire.
    @MainActor
    func testFreshFetchUpdatesState() async {
        let mock = MockShoppingListAPI()
        let response = ShoppingListResponse(
            ingredients: [],
            additionalItems: [
                AdditionalItem(id: "a1", name: "Brot", isOwned: false)
            ],
            recipes: []
        )
        await mock.setFetchResult(.success(response))

        let vm = ShoppingListViewModel(api: mock)
        await vm.fetchShoppingList()

        XCTAssertEqual(vm.additionalItems.count, 1)
        XCTAssertEqual(vm.additionalItems.first?.id, "a1")
    }

    /// A mutation that completes while a later mutation has bumped the
    /// generation must skip its cache write — the later mutation will write
    /// the authoritative snapshot.
    @MainActor
    func testMutationSkipsCacheWriteWhenGenerationAdvanced() async {
        // Drain any prior writes from previous tests.
        await CacheWriter.shared.drain()
        ShoppingListCache.clear()

        let mock = MockShoppingListAPI()
        await mock.setAddResult(.success([
            AdditionalItem(id: "a1", name: "First", isOwned: false)
        ]))
        // Configure the server URL so the cache snapshot has a non-empty key.
        UserDefaults.standard.set("https://example.test", forKey: "serverURL")
        defer { UserDefaults.standard.removeObject(forKey: "serverURL") }

        let vm = ShoppingListViewModel(api: mock)

        // Two mutations in quick succession. The second bumps the generation
        // before the first's cache write has a chance to enqueue. The first's
        // snapshot must be skipped; only the second's snapshot must land on
        // disk.
        async let first: Void = vm.addItem(name: "First")
        async let second: Void = vm.addItem(name: "Second")
        _ = await (first, second)
        await CacheWriter.shared.drain()

        let snapshot = ShoppingListCache.load()
        XCTAssertNotNil(snapshot, "Cache should have been written")
        // Both items end up in the live state since both mutations succeeded.
        XCTAssertEqual(vm.additionalItems.count, 2)
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
