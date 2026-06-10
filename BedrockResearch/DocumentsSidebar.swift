import SwiftUI

struct DocumentsSidebar: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    private var filtered: [DocumentMeta] {
        guard !searchText.isEmpty else { return appState.documents }
        return appState.documents.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.shortName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filtered) { doc in
            DocumentRow(doc: doc)
                .contextMenu {
                    Button("Filter to this document") {
                        appState.applyFilter([FilterClause(key: "short_name", op: "=", value: doc.shortName)])
                    }
                }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search documents")
        .overlay {
            if appState.documents.isEmpty {
                ContentUnavailableView("No Documents", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}

private struct DocumentRow: View {
    let doc: DocumentMeta
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(doc.title)
                .lineLimit(2)
                .font(.body)
            HStack(spacing: 6) {
                if let year = doc.year { Text(String(year)).font(.caption).foregroundStyle(.secondary) }
                if let t = doc.docType { Text(t).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(doc.shortName).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .onTapGesture(count: 2) { showDetail = true }
        .sheet(isPresented: $showDetail) {
            DocumentDetailSheet(doc: doc)
        }
    }
}

private struct DocumentDetailSheet: View {
    @Environment(AppState.self) private var appState
    let doc: DocumentMeta
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(doc.title).font(.title2).bold()
                Spacer()
                Button("Done") { dismiss() }
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Short name").foregroundStyle(.secondary)
                    Text(doc.shortName).fontDesign(.monospaced)
                }
                if let year = doc.year {
                    GridRow {
                        Text("Year").foregroundStyle(.secondary)
                        Text(String(year))
                    }
                }
                if let t = doc.docType {
                    GridRow {
                        Text("Type").foregroundStyle(.secondary)
                        Text(t)
                    }
                }
                if let org = doc.issuingOrg {
                    GridRow {
                        Text("Issuing org").foregroundStyle(.secondary)
                        Text(org)
                    }
                }
            }

            Button("Filter to this document") {
                appState.applyFilter([FilterClause(key: "short_name", op: "=", value: doc.shortName)])
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}
