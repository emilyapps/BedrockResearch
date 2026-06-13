import SwiftUI

struct ChatInputView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var filterText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            // Active filter chips
            if !appState.activeFilter.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appState.activeFilter) { clause in
                            FilterChip(clause: clause) {
                                appState.clearFilter()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .background(.quaternary.opacity(0.4))
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Add filter button
                HStack(spacing: 0) {
                    Button {
                        appState.filterPopoverShown = true
                    } label: {
                        Image(systemName: appState.activeFilter.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(appState.activeFilter.isEmpty ? Color.secondary : appState.accentColor)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $appState.filterPopoverShown) {
                        FilterPopover(filterText: $filterText) { clauses in
                            appState.applyFilter(clauses)
                            appState.filterPopoverShown = false
                            filterText = ""
                        }
                    }
                }
                .help(appState.activeFilter.isEmpty
                    ? "Filter results by document metadata (year, doc_type, short_name)"
                    : "Filter active — only matching documents are searched")

                // Auto-expanding text input
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Ask a question…")
                            .appFont(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $inputText)
                        .appFont(.body)
                        .frame(minHeight: 22, maxHeight: 80)
                        .scrollContentBackground(.hidden)
                        .focused($inputFocused)
                        .onKeyPress(.return) {
                            if NSEvent.modifierFlags.contains(.shift) {
                                return .ignored
                            }
                            submit()
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            guard appState.queryInFlight else { return .ignored }
                            appState.cancelQuery()
                            return .handled
                        }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))

                // Recipe picker + send
                HStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Menu {
                            ForEach(Recipe.allCases) { recipe in
                                let outlineDisabled = recipe == .outline && appState.filteredShortName == nil
                                Button {
                                    appState.selectedRecipe = recipe
                                } label: {
                                    HStack {
                                        Text(recipe.rawValue)
                                        if appState.selectedRecipe == recipe {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .disabled(outlineDisabled)
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                    .help("Select search tool, or let the assistant pick the best approach for your question (Auto).")

                    Button {
                        if appState.queryInFlight {
                            appState.cancelQuery()
                        } else {
                            submit()
                        }
                    } label: {
                        Image(systemName: appState.queryInFlight ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(appState.queryInFlight || canSend ? appState.accentColor : Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend && !appState.queryInFlight)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
        .onAppear { inputFocused = true }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.queryInFlight
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !appState.queryInFlight else { return }
        inputText = ""
        appState.sendQuery(text)
    }
}

private struct FilterChip: View {
    @Environment(AppState.self) private var appState
    let clause: FilterClause
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("\(clause.key) \(clause.op) \(clause.value)")
                .appFont(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(appState.accentColor.opacity(0.15), in: Capsule())
        .foregroundStyle(appState.accentColor)
        .help("Only documents where \(clause.key) \(clause.op) \(clause.value) are searched")
    }
}

private struct FilterPopover: View {
    @Binding var filterText: String
    let onSubmit: ([FilterClause]) -> Void

    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add filter").appFont(.headline)

            TextField("e.g. year >= 2010", text: $filterText)
                .appFont(.body)
                .textFieldStyle(.roundedBorder)
                .onSubmit { trySubmit() }
                .frame(width: 220)

            Text("Fields: year, doc_type, short_name\nOperators: =, >=, <=, !=")
                .appFont(.caption)
                .foregroundStyle(.secondary)

            if let err = error {
                Text(err).appFont(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Apply") { trySubmit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
    }

    private func trySubmit() {
        let clauses = parseFilter(filterText)
        if clauses.isEmpty {
            error = "Could not parse filter — check format."
            return
        }
        error = nil
        onSubmit(clauses)
    }

    private func parseFilter(_ text: String) -> [FilterClause] {
        let ops = [">=", "<=", "!=", "="]
        var result: [FilterClause] = []
        for token in text.split(separator: " ") {
            let t = String(token)
            for op in ops {
                if let range = t.range(of: op) {
                    let key = String(t[t.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let val = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty && !val.isEmpty {
                        result.append(FilterClause(key: key, op: op, value: val))
                        break
                    }
                }
            }
        }
        return result
    }
}
