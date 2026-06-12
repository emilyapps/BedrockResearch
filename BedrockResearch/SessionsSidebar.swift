import SwiftUI

struct SessionsSidebar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(appState.sessions, selection: Binding(
            get: { appState.selectedSession?.id },
            set: { id in appState.selectedSession = appState.sessions.first { $0.id == id } }
        )) { session in
            SessionRow(session: session)
                .tag(session.id)
                .onTapGesture(count: 2) {
                    resumeSession(session)
                }
                .contextMenu {
                    Button("Resume Session") { resumeSession(session) }
                }
        }
        .listStyle(.sidebar)
        .overlay {
            if appState.sessions.isEmpty {
                ContentUnavailableView("No Saved Sessions", systemImage: "clock.arrow.circlepath",
                                       description: Text("Sessions are saved when you start a new chat."))
            }
        }
    }

    private func resumeSession(_ session: SessionSummary) {
        guard !appState.queryInFlight else { return }
        Task { @MainActor in
            do {
                let newId = try await appState.client.resumeSession(session.id)
                appState.currentSessionId = newId
                appState.chatEntries = []
                appState.pinnedSources = []
                appState.pinnedTrace = []

                // Load prior messages for display
                let data = try await appState.client.fetchSession(session.id)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    for result in results {
                        let q = result["question"] as? String ?? ""
                        let a = result["answer"] as? String ?? ""
                        let qId = UUID()
                        let aId = UUID()
                        appState.chatEntries.append(.userMessage(id: qId, text: q))
                        var sources: [SourceNode] = []
                        if let srcArr = result["sources"] as? [[String: Any]],
                           let srcData = try? JSONSerialization.data(withJSONObject: srcArr),
                           let nodes = try? JSONDecoder().decode([SourceNode].self, from: srcData) {
                            sources = nodes
                        }
                        var traceCalls: [TraceCall] = []
                        if let trace = result["trace"] as? [String: Any],
                           let perCall = trace["per_call"] as? [[String: Any]],
                           let traceData = try? JSONSerialization.data(withJSONObject: perCall),
                           var calls = try? JSONDecoder().decode([TraceCall].self, from: traceData) {
                            for i in calls.indices { calls[i].index = i }
                            traceCalls = calls
                        }
                        appState.chatEntries.append(.assistantMessage(id: aId, text: a, sources: sources, traceCalls: traceCalls))
                    }
                }

                // Populate the inspector with the most recent exchange
                if let last = appState.chatEntries.last {
                    appState.pinMessage(last)
                }
            } catch {
                // silently fail — session may no longer exist
            }
        }
    }
}

private struct SessionRow: View {
    let session: SessionSummary

    private var dateString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: session.timestamp) {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
        return session.timestamp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.firstQuery)
                .lineLimit(2)
                .appFont(.body)
            HStack {
                Text(dateString)
                    .foregroundStyle(.secondary)
                    .appFont(.caption)
                Spacer()
                Text("\(session.messageCount) msgs")
                    .foregroundStyle(.secondary)
                    .appFont(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
