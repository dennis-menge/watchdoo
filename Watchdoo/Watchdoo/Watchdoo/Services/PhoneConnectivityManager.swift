import Combine
import Foundation
import WatchConnectivity

/// Manages WatchConnectivity from the iPhone side.
class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    @Published var isWatchReachable = false
    @Published var sendStatus: SendStatus = .idle

    enum SendStatus: Equatable {
        case idle
        case sending
        case success
        case error(String)
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// Send server configuration to the paired Watch.
    func sendConfig(serverURL: String, apiKey: String) {
        guard WCSession.default.activationState == .activated else {
            sendStatus = .error(String(localized: "Watch-Verbindung nicht aktiv"))
            return
        }
        guard WCSession.default.isPaired else {
            sendStatus = .error(String(localized: "Keine Apple Watch gekoppelt"))
            return
        }
        guard WCSession.default.isWatchAppInstalled else {
            sendStatus = .error(String(localized: "Watchdoo App nicht installiert"))
            return
        }

        sendStatus = .sending

        let config: [String: Any] = [
            "serverURL": serverURL,
            "apiKey": apiKey,
        ]

        // transferUserInfo guarantees delivery even if Watch is not reachable now
        WCSession.default.transferUserInfo(config)

        // Also update application context for immediate access
        try? WCSession.default.updateApplicationContext(config)

        sendStatus = .success
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }
}
