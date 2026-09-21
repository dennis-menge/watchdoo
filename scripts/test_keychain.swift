import Foundation

@main
struct KeychainRegression {
    static func main() throws {
        let service = "Watchdoo.Test.\(UUID().uuidString)"
        let suite = "Watchdoo.Test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            try? APIKeyStore.save("", service: service)
            defaults.removePersistentDomain(forName: suite)
        }
        func check(_ condition: Bool) { precondition(condition, "Keychain regression") }
        check(try APIKeyStore.load(service: service) == nil)
        // This is a test fixture, not a real credential.
        defaults.set("fixture-legacy", forKey: "apiKey")
        check(try APIKeyStore.migrate(defaults: defaults, service: service) == "fixture-legacy")
        check(defaults.object(forKey: "apiKey") == nil)
        try APIKeyStore.save("fixture-updated", service: service)
        check(try APIKeyStore.load(service: service) == "fixture-updated")
        defaults.set("fixture-stale", forKey: "apiKey")
        check(try APIKeyStore.migrate(defaults: defaults, service: service) == "fixture-updated")
        check(defaults.object(forKey: "apiKey") == nil)
        try APIKeyStore.save("", service: service)
        check(try APIKeyStore.load(service: service) == nil)
        print("Keychain save/read/update/delete and plaintext migration passed")
    }
}
