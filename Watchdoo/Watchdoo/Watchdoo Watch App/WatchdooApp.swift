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
    @Environment(\.scenePhase) private var scenePhase

    private var isConfigured: Bool {
        !serverURL.isEmpty && !((try? APIKeyStore.load()) ?? "").isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let error = connectivityManager.configurationError {
                    Text(error).font(.caption).padding()
                } else if !isConfigured {
                    SetupPromptView()
                } else {
                    ShoppingListView(viewModel: viewModel)
                }
            }
            .onChange(of: serverURL) {
                Task {
                    await viewModel.resetForConfigurationChange()
                    if isConfigured {
                        await viewModel.fetchShoppingList()
                    }
                }
            }
            .onChange(of: connectivityManager.configurationRevision) {
                Task {
                    await viewModel.resetForConfigurationChange()
                    if isConfigured {
                        await viewModel.fetchShoppingList()
                    }
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
