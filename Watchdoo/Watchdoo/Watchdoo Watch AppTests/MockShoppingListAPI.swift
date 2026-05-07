import Foundation
@testable import Watchdoo_Watch_App

/// Test double for ShoppingListAPI with controllable suspension points and
/// per-method results.
///
/// Use `setFetchSuspends(true)` to make `fetchShoppingList()` block on a
/// continuation until `releaseFetch(...)` is called from the test. All other
/// methods return their currently-set result immediately. This is enough to
/// drive race-condition tests deterministically without sleeping.
actor MockShoppingListAPI: ShoppingListAPI {

    enum MockError: Error { case noResultConfigured }

    // MARK: - Configurable results

    private var fetchResult: Result<ShoppingListResponse, Error> = .success(.empty)
    private var toggleIngredientResult: Result<[IngredientItem], Error> = .success([])
    private var toggleAdditionalResult: Result<[AdditionalItem], Error> = .success([])
    private var addResult: Result<[AdditionalItem], Error> = .success([])
    private var addResults: [Result<[AdditionalItem], Error>] = []
    private var removeAdditionalResult: Result<Void, Error> = .success(())
    private var removeRecipeResult: Result<Void, Error> = .success(())
    private var clearResult: Result<Void, Error> = .success(())

    // MARK: - Suspension control

    private var fetchSuspends = false
    private var fetchContinuation: CheckedContinuation<Void, Never>?
    private var fetchStartedContinuations: [CheckedContinuation<Void, Never>] = []

    /// Number of times each endpoint has been called.
    private(set) var fetchCallCount = 0

    func setFetchResult(_ result: Result<ShoppingListResponse, Error>) {
        fetchResult = result
    }

    func setFetchSuspends(_ suspends: Bool) {
        fetchSuspends = suspends
    }

    /// Resume any in-flight `fetchShoppingList()` calls.
    func releaseFetch() {
        fetchContinuation?.resume()
        fetchContinuation = nil
    }

    /// Block until `fetchShoppingList()` has actually entered the function
    /// (i.e. fetchCallCount has been incremented). Use instead of
    /// `Task.yield()` to deterministically order test steps relative to a
    /// suspended fetch.
    func waitForFetchStart() async {
        if fetchCallCount > 0 { return }
        await withCheckedContinuation { c in
            fetchStartedContinuations.append(c)
        }
    }

    func setToggleIngredientResult(_ result: Result<[IngredientItem], Error>) {
        toggleIngredientResult = result
    }

    func setAddResult(_ result: Result<[AdditionalItem], Error>) {
        addResult = result
    }

    /// Set a queue of per-call results for `addAdditionalItems`. Each call
    /// pops one result. After the queue is empty, `addResult` is used as
    /// fallback. Useful when a test issues several `addItem` calls and needs
    /// each to return a distinct item.
    func enqueueAddResults(_ results: [Result<[AdditionalItem], Error>]) {
        addResults.append(contentsOf: results)
    }

    // MARK: - ShoppingListAPI

    func fetchShoppingList() async throws -> ShoppingListResponse {
        fetchCallCount += 1
        // Notify any test that was waiting for the fetch to start.
        for c in fetchStartedContinuations { c.resume() }
        fetchStartedContinuations.removeAll()

        if fetchSuspends {
            await withCheckedContinuation { c in
                fetchContinuation = c
            }
        }
        return try fetchResult.get()
    }

    func toggleIngredientOwnership(id: String, isOwned: Bool) async throws -> [IngredientItem] {
        return try toggleIngredientResult.get()
    }

    func toggleAdditionalItemOwnership(id: String, isOwned: Bool) async throws -> [AdditionalItem] {
        return try toggleAdditionalResult.get()
    }

    func addAdditionalItems(names: [String]) async throws -> [AdditionalItem] {
        if !addResults.isEmpty {
            return try addResults.removeFirst().get()
        }
        return try addResult.get()
    }

    func removeAdditionalItem(id: String) async throws {
        try removeAdditionalResult.get()
    }

    func removeRecipeIngredients(recipeId: String) async throws {
        try removeRecipeResult.get()
    }

    func clearShoppingList() async throws {
        try clearResult.get()
    }
}

extension ShoppingListResponse {
    static let empty = ShoppingListResponse(ingredients: [], additionalItems: [], recipes: [])
}
