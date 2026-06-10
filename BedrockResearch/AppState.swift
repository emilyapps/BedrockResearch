import Foundation
import Observation

@Observable
final class AppState {

    // MARK: - Connection settings (persisted to UserDefaults)

    var host: String = UserDefaults.standard.string(forKey: "host") ?? "127.0.0.1" {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    var port: Int = UserDefaults.standard.integer(forKey: "port") == 0
        ? 8765
        : UserDefaults.standard.integer(forKey: "port") {
        didSet { UserDefaults.standard.set(port, forKey: "port") }
    }
    var apiToken: String = KeychainHelper.load(key: "api_token") ?? "" {
        didSet { KeychainHelper.save(apiToken, key: "api_token") }
    }

    // MARK: - Server

    var serverStatus: ServerStatus = .unknown
    var displayName: String = ""
    private var healthRetryTask: Task<Void, Never>?

    // MARK: - Session

    var currentSessionId: String? = nil
    var queryInFlight: Bool = false

    // MARK: - Chat

    var chatEntries: [ChatEntry] = []
    var pendingMilestone: String? = nil

    // MARK: - Left sidebar

    enum SidebarTab { case sessions, documents }
    var sidebarTab: SidebarTab = .sessions
    var sessions: [SessionSummary] = []
    var documents: [DocumentMeta] = []
    var selectedSession: SessionSummary? = nil

    // MARK: - Right inspector

    var inspectorVisible: Bool = true
    enum InspectorTab { case sources, trace }
    var inspectorTab: InspectorTab = .sources
    var pinnedSources: [SourceNode] = []
    var pinnedTrace: [TraceCall] = []

    // MARK: - Filter

    var activeFilter: [FilterClause] = []
    var filterPopoverShown: Bool = false

    // MARK: - Recipe

    var selectedRecipe: Recipe = .auto

    // MARK: - Settings sheet

    var settingsShown: Bool = false

    // MARK: - API client

    private(set) var client: APIClient

    init() {
        self.client = APIClient(
            host: UserDefaults.standard.string(forKey: "host") ?? "127.0.0.1",
            port: UserDefaults.standard.integer(forKey: "port") == 0 ? 8765 : UserDefaults.standard.integer(forKey: "port"),
            apiToken: KeychainHelper.load(key: "api_token") ?? ""
        )
    }

    // MARK: - Actions

    func rebuildClient() {
        client = APIClient(host: host, port: port, apiToken: apiToken)
    }

    func pingHealth() {
        Task { @MainActor in
            await _pingHealth()
        }
    }

    @MainActor
    private func _pingHealth() async {
        do {
            let info = try await client.fetchHealth()
            serverStatus = .online
            displayName = info.displayName
        } catch {
            serverStatus = .offline
            scheduleHealthRetry()
        }
    }

    func scheduleHealthRetry() {
        healthRetryTask?.cancel()
        healthRetryTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await _pingHealth()
        }
    }

    func loadSessions() {
        Task { @MainActor in
            guard let sessions = try? await client.fetchSessions() else { return }
            self.sessions = sessions
        }
    }

    func loadDocuments() {
        Task { @MainActor in
            guard let docs = try? await client.fetchDocuments() else { return }
            self.documents = docs
        }
    }

    func sendQuery(_ text: String) {
        guard !queryInFlight else { return }
        queryInFlight = true
        pendingMilestone = "Routing query…"

        let userEntryId = UUID()
        chatEntries.append(.userMessage(id: userEntryId, text: text))

        let sessionId = currentSessionId
        let toolName = selectedRecipe.toolName

        Task { @MainActor in
            var collectedSources: [SourceNode] = []
            var collectedTrace: [TraceCall] = []
            var traceIndex = 0

            let (stream, sessionIdHeader) = await client.query(text: text, sessionId: sessionId, tool: toolName)

            do {
                for try await event in stream {
                    switch event {
                    case .session(let id, _):
                        if self.currentSessionId == nil {
                            self.currentSessionId = id
                        }

                    case .routing(let q):
                        self.pendingMilestone = "Routing query…"
                        var call = TraceCall(tool: nil, query: q, filters: nil, variants: nil)
                        call.index = traceIndex; traceIndex += 1
                        collectedTrace.append(call)

                    case .toolSelected(let tool):
                        self.pendingMilestone = "Using \(tool.replacingOccurrences(of: "_", with: " "))…"
                        if let last = collectedTrace.indices.last {
                            collectedTrace[last] = TraceCall(tool: tool, query: collectedTrace[last].query, filters: nil, variants: nil)
                        }

                    case .retrieving(let q):
                        let suffix = collectedTrace.filter { $0.tool != nil }.count
                        self.pendingMilestone = suffix > 1 ? "Retrieving (\(suffix) sub-queries)…" : "Retrieving…"
                        var call = TraceCall(tool: nil, query: q, filters: self.activeFilter.isEmpty ? nil : self.activeFilter, variants: nil)
                        call.index = traceIndex; traceIndex += 1
                        collectedTrace.append(call)

                    case .answer(let text):
                        self.pendingMilestone = nil
                        let answerId = UUID()
                        self.chatEntries.append(.assistantMessage(id: answerId, text: text, sources: [], traceCalls: collectedTrace))

                    case .sources(let nodes):
                        collectedSources = nodes
                        if let last = self.chatEntries.indices.last,
                           case .assistantMessage(let id, let t, _, let tc) = self.chatEntries[last] {
                            self.chatEntries[last] = .assistantMessage(id: id, text: t, sources: nodes, traceCalls: tc)
                        }
                        self.pinnedSources = nodes
                        self.pinnedTrace = collectedTrace

                    case .error(let msg):
                        self.pendingMilestone = nil
                        let errId = UUID()
                        self.chatEntries.append(.assistantMessage(id: errId, text: "⚠️ \(msg)", sources: [], traceCalls: []))
                    }
                }
            } catch {
                self.pendingMilestone = nil
                let errId = UUID()
                self.chatEntries.append(.assistantMessage(id: errId, text: "⚠️ \(error.localizedDescription)", sources: [], traceCalls: []))
            }

            if self.currentSessionId == nil, let sid = sessionIdHeader() {
                self.currentSessionId = sid
            }
            _ = collectedSources
            self.queryInFlight = false
        }
    }

    func newChat() {
        guard !queryInFlight else { return }
        Task { @MainActor in
            if let id = currentSessionId {
                try? await client.endSession(id)
            }
            currentSessionId = nil
            chatEntries = []
            pendingMilestone = nil
            pinnedSources = []
            pinnedTrace = []
            activeFilter = []
            loadSessions()
        }
    }

    func pinMessage(_ entry: ChatEntry) {
        switch entry {
        case .assistantMessage(_, _, let sources, let trace):
            pinnedSources = sources
            pinnedTrace = trace
        default:
            break
        }
    }

    func applyFilter(_ clauses: [FilterClause]) {
        activeFilter = clauses
        guard let sid = currentSessionId else { return }
        Task { try? await client.putFilter(sid, filters: clauses) }
    }

    func clearFilter() {
        activeFilter = []
        guard let sid = currentSessionId else { return }
        Task { try? await client.deleteFilter(sid) }
    }
}
