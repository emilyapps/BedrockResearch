import AppKit
import SwiftUI

@main
struct BedrockResearchApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onAppear {
                    appState.pingHealth()
                    appState.loadSessions()
                    appState.loadDocuments()
                    appDelegate.appState = appState
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
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
            .tint(appState.accentColor)
            .preferredColorScheme(appState.theme.colorScheme)
    }
}

/// Persists the current session (same as "New Chat") before the app quits, so
/// in-progress conversations show up in the saved sessions list next launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState, let sessionId = appState.currentSessionId, !appState.chatEntries.isEmpty else {
            return .terminateNow
        }

        appState.cancelQuery()
        Task {
            // Race against a timeout so a stuck/offline server can't block quitting.
            await withTaskGroup(of: Void.self) { group in
                group.addTask { try? await appState.client.endSession(sessionId) }
                group.addTask { try? await Task.sleep(for: .seconds(3)) }
                await group.next()
                group.cancelAll()
            }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
