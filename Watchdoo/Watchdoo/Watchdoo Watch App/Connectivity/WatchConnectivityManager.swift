import Combine
import Foundation
import WatchConnectivity

/// Shared WatchConnectivity delegate for receiving configuration from iPhone.
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var receivedConfig = false
    @Published var configurationRevision = 0
    @Published var configurationError: String?

    override init() {
        super.init()
        do {
            _ = try APIKeyStore.migrate()
        } catch {
            configurationError = error.localizedDescription
        }
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let serverURL = userInfo["serverURL"] as? String,
              let apiKey = userInfo["apiKey"] as? String else { return }

        DispatchQueue.main.async {
            do {
                try APIKeyStore.save(apiKey)
            } catch {
                self.configurationError = error.localizedDescription
                return
            }
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
            UserDefaults.standard.removeObject(forKey: "apiKey")
            self.configurationError = nil
            self.receivedConfig = !serverURL.isEmpty && !apiKey.isEmpty
            self.configurationRevision += 1
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Also handle applicationContext as fallback
        self.session(session, didReceiveUserInfo: applicationContext)
    }
}
