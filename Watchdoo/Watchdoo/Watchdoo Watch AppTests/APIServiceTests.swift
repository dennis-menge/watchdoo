import XCTest
@testable import Watchdoo_Watch_App

/// Tests for APIService error types.
final class APIServiceTests: XCTestCase {

    func testAPIErrorDescriptions() {
        let errors: [(APIError, String)] = [
            (.notConfigured, "Server nicht konfiguriert"),
            (.invalidURL, "Ungültige Server-URL"),
            (.invalidResponse, "Ungültige Server-Antwort"),
            (.unauthorized, "Ungültiger API-Key"),
            (.cookidooError, "Cookidoo-Verbindung fehlgeschlagen"),
            (.serverError(statusCode: 500), "Server-Fehler (500)"),
        ]

        for (error, expectedSubstring) in errors {
            XCTAssertTrue(
                error.localizedDescription.contains(expectedSubstring),
                "Expected '\(expectedSubstring)' in '\(error.localizedDescription)'"
            )
        }
    }

    func testIsConfiguredReturnsFalseByDefault() async {
        // UserDefaults should not have serverURL/apiKey set in test environment
        let isConfigured = await APIService.shared.isConfigured
        XCTAssertFalse(isConfigured)
    }
}
