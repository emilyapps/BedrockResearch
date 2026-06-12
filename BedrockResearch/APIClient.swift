import Foundation

actor APIClient {
    var host: String
    var port: Int
    var apiToken: String

    init(host: String = "127.0.0.1", port: Int = 8765, apiToken: String = "") {
        self.host = host
        self.port = port
        self.apiToken = apiToken
    }

    private var base: String { "http://\(host):\(port)" }

    private func request(_ path: String, method: String = "GET", body: (some Encodable)? = Optional<String>.none) throws -> URLRequest {
        guard let url = URL(string: base + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if !apiToken.isEmpty {
            req.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    // MARK: - Health

    func fetchHealth() async throws -> ServerInfo {
        var req = URLRequest(url: URL(string: base + "/health")!)
        req.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(ServerInfo.self, from: data)
    }

    // MARK: - Documents

    func fetchDocuments() async throws -> [DocumentMeta] {
        let req = try request("/documents")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([DocumentMeta].self, from: data)
    }

    // MARK: - Sessions

    func fetchSessions() async throws -> [SessionSummary] {
        let req = try request("/sessions")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([SessionSummary].self, from: data)
    }

    func fetchSession(_ id: String) async throws -> Data {
        let req = try request("/sessions/\(id)")
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    func resumeSession(_ savedId: String) async throws -> String {
        let req = try request("/sessions/\(savedId)/resume", method: "POST")
        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = try JSONDecoder().decode([String: String].self, from: data)
        guard let newId = obj["session_id"] else { throw URLError(.cannotParseResponse) }
        return newId
    }

    func endSession(_ id: String) async throws {
        let req = try request("/sessions/\(id)", method: "DELETE")
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Filter

    func getFilter(_ sessionId: String) async throws -> [FilterClause] {
        let req = try request("/sessions/\(sessionId)/filter")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(FilterResponse.self, from: data)
        return resp.filters ?? []
    }

    func putFilter(_ sessionId: String, filters: [FilterClause]) async throws {
        struct Body: Encodable { let filters: [FilterClause] }
        let req = try request("/sessions/\(sessionId)/filter", method: "PUT", body: Body(filters: filters))
        _ = try await URLSession.shared.data(for: req)
    }

    func deleteFilter(_ sessionId: String) async throws {
        let req = try request("/sessions/\(sessionId)/filter", method: "DELETE")
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Query (SSE)

    func query(
        text: String,
        sessionId: String?,
        tool: String?,
        shortName: String? = nil
    ) -> (stream: AsyncThrowingStream<SSEEvent, Error>, sessionIdHeader: () -> String?, cancel: () -> Void) {
        struct QueryBody: Encodable {
            let query: String
            let session_id: String?
            let tool: String?
            let short_name: String?
        }

        var capturedSessionId: String? = nil
        var task: Task<Void, Never>? = nil

        let stream = AsyncThrowingStream<SSEEvent, Error> { continuation in
            task = Task {
                do {
                    var req = URLRequest(url: URL(string: self.base + "/query")!)
                    req.httpMethod = "POST"
                    // Default 60s "no data received" timeout is too short for
                    // agentic pipelines with long gaps between milestone events.
                    req.timeoutInterval = 600
                    if !self.apiToken.isEmpty {
                        req.setValue("Bearer \(self.apiToken)", forHTTPHeaderField: "Authorization")
                    }
                    req.httpBody = try JSONEncoder().encode(QueryBody(query: text, session_id: sessionId, tool: tool, short_name: shortName))
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    if let http = response as? HTTPURLResponse {
                        capturedSessionId = http.value(forHTTPHeaderField: "X-Session-Id")
                    }

                    var eventName: String? = nil
                    var dataLines: [String] = []

                    // Flushes the currently-buffered event (if any) and yields it.
                    // Returns true if the stream should stop (error/trace).
                    // Some transports don't deliver the SSE blank-line separator as its
                    // own line, so we also flush whenever a new "event:" line starts and
                    // once more at end-of-stream.
                    func flushPendingEvent() -> Bool {
                        guard let name = eventName else { return false }
                        let jsonString = dataLines.joined()
                        dataLines = []
                        eventName = nil
                        guard let jsonData = jsonString.data(using: .utf8),
                              let event = Self.parseSSEEvent(name: name, data: jsonData) else {
                            return false
                        }
                        continuation.yield(event)
                        switch event {
                        case .error, .trace: return true
                        default: return false
                        }
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            if flushPendingEvent() { break }
                            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                        } else if line.isEmpty {
                            if flushPendingEvent() { break }
                        }
                    }
                    _ = flushPendingEvent()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        return (stream, { capturedSessionId }, { task?.cancel() })
    }

    // MARK: - SSE parsing

    private static func parseSSEEvent(name: String, data: Data) -> SSEEvent? {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        switch name {
        case "session":
            guard let id = json?["session_id"] as? String,
                  let dn = json?["display_name"] as? String else { return nil }
            return .session(id: id, displayName: dn)

        case "routing":
            return .routing(query: json?["query"] as? String ?? "")

        case "tool_selected":
            return .toolSelected(tool: json?["tool"] as? String ?? "")

        case "retrieving":
            return .retrieving(query: json?["query"] as? String ?? "")

        case "answer":
            guard let text = json?["answer"] as? String else { return nil }
            return .answer(text: text)

        case "sources":
            guard let arr = json?["sources"] as? [[String: Any]],
                  let sourcesData = try? JSONSerialization.data(withJSONObject: arr),
                  let nodes = try? JSONDecoder().decode([SourceNode].self, from: sourcesData) else { return nil }
            return .sources(nodes)

        case "trace":
            guard let arr = json?["per_call"] as? [[String: Any]] else {
                return .trace(calls: [])
            }
            guard let traceData = try? JSONSerialization.data(withJSONObject: arr),
                  var calls = try? JSONDecoder().decode([TraceCall].self, from: traceData) else { return nil }
            for i in calls.indices { calls[i].index = i }
            return .trace(calls: calls)

        case "error":
            return .error(message: json?["message"] as? String ?? "Unknown error")

        default:
            return nil
        }
    }
}
