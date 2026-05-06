import Foundation

/// Persistent on-disk cache for the shopping list response.
///
/// Stored in the app's Caches directory as JSON. The system may evict the file
/// under storage pressure — that's fine because the data is re-derivable from
/// the backend.
///
/// The snapshot also records the server URL it came from so we never serve a
/// cache from a different backend (e.g. after the user reconfigures the app).
enum ShoppingListCache {
    struct Snapshot: Codable {
        let response: ShoppingListResponse
        let fetchedAt: Date
        let serverURL: String
    }

    private static let filename = "shopping_list_cache.json"

    private static var fileURL: URL? {
        guard let dir = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return dir.appendingPathComponent(filename)
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func load() -> Snapshot? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Snapshot.self, from: data)
    }

    static func save(_ response: ShoppingListResponse, serverURL: String) {
        guard let url = fileURL else { return }
        let snapshot = Snapshot(response: response, fetchedAt: Date(), serverURL: serverURL)
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
