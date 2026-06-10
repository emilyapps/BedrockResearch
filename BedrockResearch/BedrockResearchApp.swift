import SwiftUI

@main
struct BedrockResearchApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
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
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
