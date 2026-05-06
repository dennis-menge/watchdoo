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
    private var removeAdditionalResult: Result<Void, Error> = .success(())
    private var removeRecipeResult: Result<Void, Error> = .success(())
    private var clearResult: Result<Void, Error> = .success(())

    // MARK: - Suspension control

    private var fetchSuspends = false
    private var fetchContinuation: CheckedContinuation<Void, Never>?

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

    func setToggleIngredientResult(_ result: Result<[IngredientItem], Error>) {
        toggleIngredientResult = result
    }

    func setAddResult(_ result: Result<[AdditionalItem], Error>) {
        addResult = result
    }

    // MARK: - ShoppingListAPI

    func fetchShoppingList() async throws -> ShoppingListResponse {
        fetchCallCount += 1
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
