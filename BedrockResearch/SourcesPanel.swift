import SwiftUI

struct SourcesPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.pinnedSources.isEmpty {
            ContentUnavailableView(
                "No Sources",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Tap a response to pin its sources here.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.pinnedSources) { node in
                        SourceNodeRow(node: node)
                        if node.id != appState.pinnedSources.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

struct SourceNodeRow: View {
    let node: SourceNode
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("#\(node.rank)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue, in: Capsule())

                Text(node.shortName ?? node.file)
                    .font(.callout.bold())
                    .lineLimit(1)

                Spacer()

                if let score = node.score {
                    Text(String(format: "%.3f", score))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(expanded ? node.text : String(node.text.prefix(150)) + (node.text.count > 150 ? "…" : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)

            if node.text.count > 150 {
                Button(expanded ? "Show less" : "Show more") {
                    withAnimation { expanded.toggle() }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
