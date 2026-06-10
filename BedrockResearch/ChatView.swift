import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(appState.chatEntries) { entry in
                            ChatBubbleView(entry: entry)
                                .environment(appState)
                                .id(entry.id)
                        }

                        if let milestone = appState.pendingMilestone {
                            MilestoneBubble(text: milestone)
                                .id("milestone")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .onChange(of: appState.chatEntries.count) {
                    withAnimation {
                        if let last = appState.chatEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: appState.pendingMilestone) {
                    if appState.pendingMilestone != nil {
                        withAnimation { proxy.scrollTo("milestone", anchor: .bottom) }
                    }
                }
            }

            Divider()

            ChatInputView()
                .environment(appState)
        }
    }
}

private struct ChatBubbleView: View {
    @Environment(AppState.self) private var appState
    let entry: ChatEntry

    var body: some View {
        switch entry {
        case .userMessage(_, let text):
            HStack {
                Spacer(minLength: 60)
                Text(text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
            }

        case .assistantMessage(_, let text, let sources, _):
            VStack(alignment: .leading, spacing: 6) {
                Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !sources.isEmpty {
                    Button {
                        appState.pinMessage(entry)
                        appState.inspectorTab = .sources
                        appState.inspectorVisible = true
                    } label: {
                        Label("\(sources.count) source\(sources.count == 1 ? "" : "s")", systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 14)
                }
            }
        }
    }
}

private struct MilestoneBubble: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 16, height: 16)
            Text(text)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: text)
    }
}
