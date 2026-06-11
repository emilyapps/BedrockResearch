import SwiftUI

struct TracePanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.pinnedTrace.isEmpty {
            ContentUnavailableView(
                "No Trace",
                systemImage: "list.bullet.rectangle",
                description: Text("Tap a response to see its trace here.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.pinnedTrace) { call in
                        TraceCallRow(call: call)
                        if call.id != appState.pinnedTrace.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

private struct TraceCallRow: View {
    let call: TraceCall
    @State private var answerExpanded = false

    private var hasDetail: Bool {
        call.filters != nil
            || !(call.variants ?? []).isEmpty
            || !(call.subQuestions ?? []).isEmpty
            || call.intermediateAnswer != nil
            || !(call.sources ?? []).isEmpty
    }

    private var summaryText: String {
        var parts: [String] = [(call.tool ?? "").replacingOccurrences(of: "_", with: " ")]
        if let shortName = call.shortName { parts.append(shortName) }
        if let field = call.field, let value = call.value { parts.append("\(field) = \(value)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        if hasDetail {
            VStack(alignment: .leading, spacing: 6) {
                header
                identifiers
                filtersRow
                variantsRow
                subQuestionsRow
                answerRow
                sourcesRow
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("#\(call.index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("#\(call.index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue, in: Capsule())

            Text((call.tool ?? "").replacingOccurrences(of: "_", with: " "))
                .font(.callout.bold())
        }
    }

    @ViewBuilder
    private var identifiers: some View {
        if let shortName = call.shortName {
            labeledRow("Document", shortName)
        }
        if let q = call.query {
            labeledRow("Query", q)
        }
    }

    @ViewBuilder
    private var filtersRow: some View {
        if let filters = call.filters {
            HStack(alignment: .top, spacing: 6) {
                Text("Filters")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
                if filters.isEmpty {
                    Text("none inferred")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(filters) { f in
                            Text("\(f.key) \(f.op) \(f.value)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1), in: Capsule())
                        }
                    }
                }
                if call.filterFallback == true {
                    Text("fallback: unfiltered")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var variantsRow: some View {
        if let variants = call.variants, !variants.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Text("Variants")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(variants.enumerated()), id: \.offset) { _, v in
                        Text(v).font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var subQuestionsRow: some View {
        if let subQs = call.subQuestions, !subQs.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Text("Sub-questions")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(subQs.enumerated()), id: \.offset) { i, sq in
                        Text("\(i + 1). \(sq)").font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var answerRow: some View {
        if let answer = call.intermediateAnswer {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Text("Answer")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                    Text(answerExpanded ? answer : String(answer.prefix(150)) + (answer.count > 150 ? "…" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if answer.count > 150 {
                    Button(answerExpanded ? "Show less" : "Show more") {
                        withAnimation { answerExpanded.toggle() }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .padding(.leading, 70)
                }
            }
        }
    }

    @ViewBuilder
    private var sourcesRow: some View {
        if let sources = call.sources, !sources.isEmpty {
            DisclosureGroup("\(sources.count) source\(sources.count == 1 ? "" : "s")") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sources) { node in
                        SourceNodeRow(node: node)
                        if node.id != sources.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.leading, 8)
            }
            .font(.caption)
        }
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            Text(value)
                .font(.caption)
        }
    }
}
