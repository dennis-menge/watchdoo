import SwiftUI
import WatchConnectivity

/// iPhone companion app for configuring the Watch app.
@main
struct WatchdooCompanionApp: App {
    @StateObject private var connectivity = PhoneConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            SetupView()
                .environmentObject(connectivity)
        }
    }
}
