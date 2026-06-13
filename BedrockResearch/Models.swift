import Foundation
import SwiftUI

// MARK: - Server / connection

enum ServerStatus {
    case unknown, online, offline
}

struct ServerInfo: Codable {
    let status: String
    let displayName: String
    let embedModel: String
    let llmModel: String

    enum CodingKeys: String, CodingKey {
        case status
        case displayName = "display_name"
        case embedModel = "embed_model"
        case llmModel = "llm_model"
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
    let parameters: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case tool, query, filters, sources, field, value, parameters
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
        parameters = try container.decodeIfPresent([String: Int].self, forKey: .parameters)
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
    case accumulate  = "Accumulate"
    case outline     = "Outline"

    var id: String { rawValue }

    var toolName: String? {
        switch self {
        case .auto:         return nil
        case .factual:      return "search_factual"
        case .thorough:     return "search_thorough"
        case .perspectives: return "search_perspectives"
        case .decompose:    return "decompose"
        case .accumulate:   return "accumulate"
        case .outline:      return "outline_document"
        }
    }

    var helpText: String {
        switch self {
        case .auto:         return "Let the assistant pick the best approach for your question; infers the right strategy and metadate filters from your questions."
        case .factual:      return "Narrow, focused lookup: auto-filter, multiquery expansion, compact synthesis (topk=16, topn=10)."
        case .thorough:     return "Broader search for a more complex Q&A: auto-filter, multiquery expansion, hierarchical synthesis (topk=40, topn=20)."
        case .perspectives: return "Surface multiple viewpoints: auto-filter, multiquery expansion, refine synthesis (each source updates the running answer (topk=30, topn=15). Expensive and slow."
        case .decompose:    return "Break an expansive question into sub-questions and synthesize an answer from each set of returned sources (retrieves in parallel, single hierarchical synthesis)."
        case .accumulate:   return "Corpus-wide sweep: retrieves globally (topk=60), groups by document, then reranks and synthesizes per document — one bullet per matching source. Good for 'what does each document say about X'."
        case .outline:      return "Comprehensive coverage of a single document: no multiquery expansion, topk=50, no reranker, hierarchical synthesis."
        }
    }
}

// MARK: - Accessibility

extension DynamicTypeSize {
    var displayName: String {
        switch self {
        case .xSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large (Default)"
        case .xLarge: return "Extra Large"
        case .xxLarge: return "XX Large"
        case .xxxLarge: return "XXX Large"
        case .accessibility1: return "Accessibility 1"
        case .accessibility2: return "Accessibility 2"
        case .accessibility3: return "Accessibility 3"
        case .accessibility4: return "Accessibility 4"
        case .accessibility5: return "Accessibility 5"
        @unknown default: return "Default"
        }
    }
}

// MARK: - Appearance

enum AppTheme: String, CaseIterable, Identifiable {
    case ocean, forest, sunset, midnight, indigo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .sunset: return "Sunset"
        case .midnight: return "Midnight"
        case .indigo: return "Indigo"
        }
    }

    var accentColor: Color {
        switch self {
        case .ocean: return Color(red: 0.14, green: 0.48, blue: 0.68)
        case .forest: return Color(red: 0.24, green: 0.56, blue: 0.31)
        case .sunset: return Color(red: 0.88, green: 0.45, blue: 0.20)
        case .midnight: return Color(red: 0.52, green: 0.43, blue: 0.82)
        case .indigo: return Color(red: 0.29, green: 0.33, blue: 0.78)
        }
    }

    /// Each theme has a fixed appearance. Avoid `nil` ("follow system") here — toggling
    /// between `nil` and an explicit value leaves NSWindow's appearance stuck on macOS,
    /// so vibrancy materials only refresh on the next window-activation event.
    var colorScheme: ColorScheme? {
        switch self {
        case .midnight, .indigo: return .dark
        case .ocean, .forest, .sunset: return .light
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
