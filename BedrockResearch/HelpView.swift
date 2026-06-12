import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("BedrockResearch Help")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Asking Questions") {
                        Text("Type your question in the box at the bottom and press Return to send. Use Shift+Return to add a new line without sending.")
                    }

                    section("Recipes") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Use the chevron menu next to the send button to choose how the assistant answers your question:")
                            ForEach(Recipe.allCases) { recipe in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                    Text("\(recipe.rawValue):").bold() + Text(" \(recipe.helpText)")
                                }
                            }
                        }
                    }

                    section("Filters") {
                        Text("Tap the funnel icon to restrict searches to documents matching a metadata filter, e.g. \"year >= 2010\" or \"short_name = ABC123\". Active filters appear as chips above the input — tap the x to remove one. Filtering to a single document by short_name also enables the Outline recipe.")
                    }

                    section("Sessions") {
                        Text("Conversations are saved automatically when you start a new chat or close the app. Resume a previous conversation from the Sessions tab in the sidebar, or start fresh with New Chat (⌘N). Resuming a session without asking anything new won't create a duplicate save.")
                    }

                    section("Sources & Trace") {
                        Text("Each answer has a \"N sources\" or \"N steps\" button. Tap it to open the inspector and see the passages the assistant used (Sources) or a step-by-step trace of the tools it called, including the embedding and language models in use (Trace).")
                    }

                    section("Accessibility") {
                        Text("Open Settings (⌘,) to adjust the app's text size for better readability.")
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 520)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }
}
