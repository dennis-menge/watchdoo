import SwiftUI

/// Main entry point for the watchOS app.
@main
struct WatchdooApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @StateObject private var viewModel = ShoppingListViewModel()
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("apiKey") private var apiKey = ""
    @Environment(\.scenePhase) private var scenePhase

    private var isConfigured: Bool {
        !serverURL.isEmpty && !apiKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if !isConfigured && !connectivityManager.receivedConfig {
                    SetupPromptView()
                } else {
                    ShoppingListView(viewModel: viewModel)
                }
            }
            .onChange(of: connectivityManager.receivedConfig) {
                if connectivityManager.receivedConfig {
                    Task { await viewModel.fetchShoppingList() }
                }
            }
            .onChange(of: isConfigured) {
                if isConfigured {
                    Task { await viewModel.fetchShoppingList() }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && isConfigured {
                    Task { await viewModel.fetchShoppingList() }
                }
            }
        }
    }
}

struct SetupPromptView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("Nicht konfiguriert")
                .font(.headline)
            Text("Bitte über die Watchdoo-App auf dem iPhone konfigurieren.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
