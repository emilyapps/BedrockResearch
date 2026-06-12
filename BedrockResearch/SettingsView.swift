import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Server") {
                TextField("Host", text: $appState.host)
                TextField("Port", value: $appState.port, format: .number)
                SecureField("API Token (optional)", text: $appState.apiToken)
            }

            Section("Accessibility") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text Size")
                        Spacer()
                        Text(appState.dynamicTypeSize.displayName)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.dynamicTypeSizeIndex) },
                            set: { appState.dynamicTypeSizeIndex = Int($0.rounded()) }
                        ),
                        in: 0...Double(DynamicTypeSize.allCases.count - 1),
                        step: 1
                    )
                }
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        appState.rebuildClient()
                        appState.pingHealth()
                    }

                    Spacer()

                    switch appState.serverStatus {
                    case .unknown:
                        Text("Not tested").foregroundStyle(.secondary)
                    case .online:
                        Label("Online — \(appState.displayName)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .offline:
                        Label("Offline", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
    }
}
