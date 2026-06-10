import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
                .environment(appState)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            ChatView()
                .environment(appState)
        }
        .inspector(isPresented: $appState.inspectorVisible) {
            InspectorView()
                .environment(appState)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 460)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.newChat()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .disabled(appState.queryInFlight)
                .help("New Chat (⌘N)")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.inspectorVisible.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
        .overlay(alignment: .top) {
            if appState.serverStatus == .offline {
                OfflineBanner()
                    .environment(appState)
            }
        }
    }
}

private struct OfflineBanner: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Server offline — start with ")
            Text("`python3 -m bedrock serve`")
                .fontDesign(.monospaced)
            Spacer()
            Button("Retry") {
                appState.pingHealth()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.85))
        .foregroundStyle(.black)
    }
}

private struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            Picker("", selection: $appState.sidebarTab) {
                Text("Sessions").tag(AppState.SidebarTab.sessions)
                Text("Documents").tag(AppState.SidebarTab.documents)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch appState.sidebarTab {
            case .sessions:
                SessionsSidebar()
                    .environment(appState)
            case .documents:
                DocumentsSidebar()
                    .environment(appState)
            }
        }
        .navigationTitle(appState.displayName.isEmpty ? "Bedrock Research" : appState.displayName)
    }
}

private struct InspectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            Picker("", selection: $appState.inspectorTab) {
                Text("Sources").tag(AppState.InspectorTab.sources)
                Text("Trace").tag(AppState.InspectorTab.trace)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch appState.inspectorTab {
            case .sources:
                SourcesPanel()
                    .environment(appState)
            case .trace:
                TracePanel()
                    .environment(appState)
            }
        }
    }
}
