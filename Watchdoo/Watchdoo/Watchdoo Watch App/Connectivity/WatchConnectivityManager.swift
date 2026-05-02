import Combine
import Foundation
import WatchConnectivity

/// Shared WatchConnectivity delegate for receiving configuration from iPhone.
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var receivedConfig = false

    override init() {
        super.init()
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
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
            UserDefaults.standard.set(apiKey, forKey: "apiKey")
            self.receivedConfig = true
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Also handle applicationContext as fallback
        self.session(session, didReceiveUserInfo: applicationContext)
    }
}
