import Foundation

// MARK: - Server / connection

enum ServerStatus {
    case unknown, online, offline
}

struct ServerInfo: Codable {
    let status: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case status
        case displayName = "display_name"
    }
}

// MARK: - Documents

struct DocumentMeta: Identifiable, Codable, Hashable {
    var id: String { shortName }
    let shortName: String
    let title: String
    let year: Int?
    let docType: String?
    let issuingOrg: String?

    enum CodingKeys: String, CodingKey {
        case shortName = "short_name"
        case title, year
        case docType = "doc_type"
        case issuingOrg = "issuing_org"
    }
}

// MARK: - Sessions

struct SessionSummary: Identifiable, Codable {
    let id: String
    let timestamp: String
    let firstQuery: String
    let messageCount: Int

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case firstQuery = "first_query"
        case messageCount = "message_count"
    }
}

// MARK: - Filter

struct FilterClause: Codable, Equatable, Identifiable {
    var id: String { "\(key)\(op)\(value)" }
    let key: String
    let op: String
    let value: String
}

struct FilterResponse: Codable {
    let filters: [FilterClause]?
}

// MARK: - Sources / retrieval

struct SourceNode: Identifiable, Codable {
    let rank: Int
    let score: Double?
    let shortName: String?
    let file: String
    let text: String

    var id: Int { rank }

    enum CodingKeys: String, CodingKey {
        case rank, score, file, text
        case shortName = "short_name"
    }
}

// MARK: - Trace

struct TraceCall: Identifiable, Codable {
    var id: Int { index }
    var index: Int = 0
    let tool: String?
    let query: String?
    let filters: [FilterClause]?
    let variants: [String]?

    enum CodingKeys: String, CodingKey {
        case tool, query, filters
        case variants = "query_variants"
    }
}

// MARK: - Chat

enum ChatEntry: Identifiable {
    case userMessage(id: UUID, text: String)
    case assistantMessage(id: UUID, text: String, sources: [SourceNode], traceCalls: [TraceCall])

    var id: UUID {
        switch self {
        case .userMessage(let id, _): return id
        case .assistantMessage(let id, _, _, _): return id
        }
    }
}

// MARK: - Recipes

enum Recipe: String, CaseIterable, Identifiable {
    case auto        = "Auto"
    case factual     = "Factual"
    case thorough    = "Thorough"
    case perspectives = "Perspectives"
    case decompose   = "Decompose"

    var id: String { rawValue }

    var toolName: String? {
        switch self {
        case .auto:         return nil
        case .factual:      return "search_factual"
        case .thorough:     return "search_thorough"
        case .perspectives: return "search_perspectives"
        case .decompose:    return "decompose"
        }
    }
}

// MARK: - SSE events

enum SSEEvent {
    case session(id: String, displayName: String)
    case routing(query: String)
    case toolSelected(tool: String)
    case retrieving(query: String)
    case answer(text: String)
    case sources([SourceNode])
    case error(message: String)
}
