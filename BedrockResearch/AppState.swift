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
    var embedModel: String = ""
    var llmModel: String = ""
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
            embedModel = info.embedModel
            llmModel = info.llmModel
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
            var toolSelectedCount = 0

            let (stream, sessionIdHeader) = await client.query(text: text, sessionId: sessionId, tool: toolName)

            do {
                for try await event in stream {
                    switch event {
                    case .session(let id, _):
                        if self.currentSessionId == nil {
                            self.currentSessionId = id
                        }

                    case .routing:
                        self.pendingMilestone = "Routing query…"

                    case .toolSelected(let tool):
                        toolSelectedCount += 1
                        self.pendingMilestone = "Using \(tool.replacingOccurrences(of: "_", with: " "))…"

                    case .retrieving:
                        self.pendingMilestone = toolSelectedCount > 1 ? "Retrieving (\(toolSelectedCount) sub-queries)…" : "Retrieving…"

                    case .answer(let text):
                        self.pendingMilestone = nil
                        let answerId = UUID()
                        self.chatEntries.append(.assistantMessage(id: answerId, text: text, sources: [], traceCalls: []))

                    case .sources(let nodes):
                        if let last = self.chatEntries.indices.last,
                           case .assistantMessage(let id, let t, _, let tc) = self.chatEntries[last] {
                            self.chatEntries[last] = .assistantMessage(id: id, text: t, sources: nodes, traceCalls: tc)
                        }
                        self.pinnedSources = nodes

                    case .trace(let calls):
                        if let last = self.chatEntries.indices.last,
                           case .assistantMessage(let id, let t, let s, _) = self.chatEntries[last] {
                            self.chatEntries[last] = .assistantMessage(id: id, text: t, sources: s, traceCalls: calls)
                        }
                        self.pinnedTrace = calls

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
