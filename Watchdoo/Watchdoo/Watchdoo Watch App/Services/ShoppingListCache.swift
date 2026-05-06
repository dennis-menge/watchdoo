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

/// Serializes all cache writes through a single FIFO chain.
///
/// Why this exists: ShoppingListViewModel runs on @MainActor and calls into
/// the cache after every fetch and every mutation. Naively dispatching each
/// write via `Task.detached` produces no ordering guarantees:
///   * two rapid mutations could write out of order, leaving an older
///     snapshot on disk;
///   * `clear()` from a configuration change could race with a still-pending
///     `save()` from the previous configuration, recreating the cache after
///     the clear was supposed to wipe it.
///
/// The actor enqueues each operation as a detached Task that first awaits
/// the previous task's completion, guaranteeing strict FIFO execution while
/// keeping the actual disk I/O off both the @MainActor and this actor's
/// executor.
actor CacheWriter {
    static let shared = CacheWriter()
    private init() {}

    private var pending: Task<Void, Never>?

    func save(_ response: ShoppingListResponse, serverURL: String) {
        let previous = pending
        pending = Task.detached(priority: .utility) {
            await previous?.value
            ShoppingListCache.save(response, serverURL: serverURL)
        }
    }

    func clear() {
        let previous = pending
        pending = Task.detached(priority: .utility) {
            await previous?.value
            ShoppingListCache.clear()
        }
    }

    /// Wait for all pending writes to complete. Useful for tests and for
    /// explicit barriers before reads that must observe all prior writes.
    func drain() async {
        await pending?.value
    }
}
