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
            List(appState.pinnedTrace) { call in
                TraceCallRow(call: call)
            }
            .listStyle(.plain)
        }
    }
}

private struct TraceCallRow: View {
    let call: TraceCall

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let tool = call.tool {
                Label(tool.replacingOccurrences(of: "_", with: " "), systemImage: "wrench.and.screwdriver")
                    .font(.callout.bold())
            }

            if let q = call.query {
                HStack(alignment: .top, spacing: 6) {
                    Text("Query")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                    Text(q)
                        .font(.caption)
                }
            }

            if let filters = call.filters, !filters.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("Filters")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
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
            }

            if let variants = call.variants, !variants.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("Variants")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(variants.enumerated()), id: \.offset) { _, v in
                            Text(v).font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
