import SwiftUI

/// Main setup view for configuring the Watch app from iPhone.
struct SetupView: View {
    @EnvironmentObject var connectivity: PhoneConnectivityManager
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("apiKey") private var apiKey = ""
    @State private var isTestingConnection = false
    @State private var connectionOk: Bool?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Watchdoo Setup", systemImage: "applewatch")
                            .font(.title2.bold())
                        Text("Konfiguriere dein Backend und sende die Einstellungen an deine Apple Watch.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Server-Konfiguration") {
                    TextField("Server-URL", text: $serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    SecureField("API-Key", text: $apiKey)
                        .textContentType(.password)

                    Button {
                        if let clipboard = UIPasteboard.general.string {
                            parseAndFillFromClipboard(clipboard)
                        }
                    } label: {
                        Label("Aus Clipboard einfügen", systemImage: "doc.on.clipboard")
                    }
                }

                Section("Verbindung testen") {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Server testen")
                        }
                    }
                    .disabled(serverURL.isEmpty || apiKey.isEmpty || isTestingConnection)

                    if let ok = connectionOk {
                        if ok {
                            Label("Verbindung erfolgreich", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Verbindung fehlgeschlagen", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }

                Section("An Watch senden") {
                    Button {
                        connectivity.sendConfig(serverURL: serverURL, apiKey: apiKey)
                    } label: {
                        HStack {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                            Text("An Watch senden")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .disabled(serverURL.isEmpty || apiKey.isEmpty)

                    statusView
                }

                Section("Hilfe") {
                    Link(destination: URL(string: "https://github.com")!) {
                        Label("Backend-Setup Anleitung", systemImage: "book")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API-Key generieren:")
                            .font(.subheadline.bold())
                        Text("openssl rand -hex 32")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("⚙️ Setup")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch connectivity.sendStatus {
        case .idle:
            EmptyView()
        case .sending:
            Label("Sende...", systemImage: "arrow.triangle.2.circlepath")
                .foregroundColor(.secondary)
        case .success:
            Label("Erfolgreich an Watch gesendet!", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }

    private func testConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }

        guard let url = URL(string: serverURL + "/api/v1/health") else {
            connectionOk = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                connectionOk = false
                return
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            connectionOk = json?["status"] as? String == "ok"
        } catch {
            connectionOk = false
        }
    }

    private func parseAndFillFromClipboard(_ text: String) {
        // Try to parse deploy.sh output format
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "https://") && serverURL.isEmpty {
                serverURL = trimmed
            } else if trimmed.contains("Server URL:") || trimmed.contains("Backend URL:") {
                if let url = trimmed.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) {
                    serverURL = url
                }
            } else if trimmed.contains("API Key:") {
                if let key = trimmed.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) {
                    apiKey = key
                }
            }
        }

        // If nothing parsed, just put it in the first empty field
        if serverURL.isEmpty && text.starts(with: "https://") {
            serverURL = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if apiKey.isEmpty && !text.contains("://") {
            apiKey = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
