import SwiftUI

@main
struct BedrockResearchApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onAppear {
                    appState.pingHealth()
                    appState.loadSessions()
                    appState.loadDocuments()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Chat") {
                    appState.newChat()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(appState.queryInFlight)
            }

            CommandGroup(replacing: .help) {
                Button("BedrockResearch Help") {
                    appState.helpShown = true
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

/// Wraps ContentView so .environment(\.dynamicTypeSize, ...) is applied inside a
/// View body, where @Observable changes to appState reliably trigger re-evaluation
/// (Scene.body does not re-run reactively when only nested observable state changes).
private struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ContentView()
            .environment(\.dynamicTypeSize, appState.dynamicTypeSize)
            .environment(\.appFontScale, appState.fontScale)
    }
}
