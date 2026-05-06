import Foundation

/// Manages communication with the Watchdoo backend.
actor APIService {
    static let shared = APIService()

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? ""
    }

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? ""
    }

    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }

    // MARK: - Shopping List

    func fetchShoppingList() async throws -> ShoppingListResponse {
        return try await request(.get, path: "/api/v1/shopping-list")
    }

    func toggleIngredientOwnership(id: String, isOwned: Bool) async throws -> [IngredientItem] {
        let body: [[String: Any]] = [["id": id, "is_owned": isOwned]]
        return try await request(.patch, path: "/api/v1/shopping-list/ingredients", body: body)
    }

    func toggleAdditionalItemOwnership(id: String, isOwned: Bool) async throws -> [AdditionalItem] {
        let body: [[String: Any]] = [["id": id, "is_owned": isOwned]]
        return try await request(.patch, path: "/api/v1/shopping-list/additional-items/ownership", body: body)
    }

    func addAdditionalItems(names: [String]) async throws -> [AdditionalItem] {
        let body: [String: [String]] = ["names": names]
        return try await request(.post, path: "/api/v1/shopping-list/additional-items", body: body)
    }

    func removeAdditionalItem(id: String) async throws {
        let _: EmptyResponse = try await request(.delete, path: "/api/v1/shopping-list/additional-items/\(id)")
        return
    }

    func removeRecipeIngredients(recipeId: String) async throws {
        let _: EmptyResponse = try await request(.delete, path: "/api/v1/shopping-list/recipes/\(recipeId)")
        return
    }

    func clearShoppingList() async throws {
        let _: EmptyResponse = try await request(.delete, path: "/api/v1/shopping-list")
        return
    }

    func checkHealth() async throws -> Bool {
        struct HealthResponse: Decodable {
            let status: String
            let cookidooConnected: Bool

            enum CodingKeys: String, CodingKey {
                case status
                case cookidooConnected = "cookidoo_connected"
            }
        }
        let response: HealthResponse = try await request(.get, path: "/api/v1/health")
        return response.status == "ok"
    }

    // MARK: - Generic Request

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    private struct EmptyResponse: Decodable {}

    private func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        body: Any? = nil
    ) async throws -> T {
        guard isConfigured else {
            throw APIError.notConfigured
        }

        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60

        if let body = body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            return try JSONDecoder().decode(T.self, from: data)
        case 401, 403:
            throw APIError.unauthorized
        case 502:
            throw APIError.cookidooError
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case unauthorized
    case cookidooError
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return String(localized: "Server nicht konfiguriert. Bitte über die iPhone-App konfigurieren.")
        case .invalidURL: return String(localized: "Ungültige Server-URL")
        case .invalidResponse: return String(localized: "Ungültige Server-Antwort")
        case .unauthorized: return String(localized: "Ungültiger API-Key")
        case .cookidooError: return String(localized: "Cookidoo-Verbindung fehlgeschlagen")
        case .serverError(let code): return String(localized: "Server-Fehler (\(code))")
        }
    }
}
