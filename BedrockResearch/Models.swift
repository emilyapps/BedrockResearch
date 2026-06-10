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

struct SourceNode: Identifiable, Decodable {
    let id = UUID()
    let rank: Int
    let score: Double?
    let shortName: String?
    let file: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case rank, score, file, text
        case shortName = "short_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decode(Int.self, forKey: .rank)
        score = try container.decodeIfPresent(Double.self, forKey: .score)
        shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
        file = try container.decode(String.self, forKey: .file)
        text = try container.decode(String.self, forKey: .text)
    }
}

// MARK: - Trace

struct TraceCall: Identifiable, Decodable {
    let id = UUID()
    var index: Int = 0
    let tool: String?
    let query: String?
    let shortName: String?
    let field: String?
    let value: String?
    let filters: [FilterClause]?
    let filterFallback: Bool?
    let variants: [String]?
    let subQuestions: [String]?
    let intermediateAnswer: String?
    let sources: [SourceNode]?

    enum CodingKeys: String, CodingKey {
        case tool, query, filters, sources, field, value
        case shortName = "short_name"
        case filterFallback = "filter_fallback"
        case variants = "query_variants"
        case subQuestions = "sub_questions"
        case intermediateAnswer = "intermediate_answer"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        query = try container.decodeIfPresent(String.self, forKey: .query)
        shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
        field = try container.decodeIfPresent(String.self, forKey: .field)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        filters = try container.decodeIfPresent([FilterClause].self, forKey: .filters)
        filterFallback = try container.decodeIfPresent(Bool.self, forKey: .filterFallback)
        variants = try container.decodeIfPresent([String].self, forKey: .variants)
        subQuestions = try container.decodeIfPresent([String].self, forKey: .subQuestions)
        intermediateAnswer = try container.decodeIfPresent(String.self, forKey: .intermediateAnswer)
        sources = try container.decodeIfPresent([SourceNode].self, forKey: .sources)
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
    case trace(calls: [TraceCall])
    case error(message: String)
}
