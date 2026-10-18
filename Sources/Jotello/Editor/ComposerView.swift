import SwiftUI

struct ComposerView: View {
    @Bindable var feedback: FeedbackModel
    let send: () -> Void
    let copyText: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Type", selection: $feedback.draft.category) {
                ForEach(FeedbackCategory.allCases) { Text($0.title).tag($0) }
            }
            field("Title") {
                TextField(feedback.draft.resolvedTitle, text: $feedback.draft.title)
                    .accessibilityHint("Optional. Generated from the description when empty.")
            }
            field("What should change?") {
                TextEditor(text: $feedback.draft.description)
                    .font(.body).scrollContentBackground(.hidden).padding(4)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
                    .frame(minHeight: 110)
                    .accessibilityLabel("Description")
            }
            field("Page URL (optional)") {
                TextField("http://localhost:3000/…", text: $feedback.draft.sourceURL)
            }
            if let app = contextLine {
                Text(app).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    .help("The app and window under your selection")
            }
            Divider()
            Picker("Send to", selection: $feedback.draft.destination) {
                ForEach(Destination.allCases) { Text($0.title).tag($0) }
            }
            if let label = feedback.draft.destination.targetLabel {
                field(label) {
                    TextField(feedback.draft.destination.targetPlaceholder, text: $feedback.draft.targetURL)
                }
            }
            Spacer(minLength: 0)
            if let status = feedback.status {
                Text(status.message).font(.callout)
                    .foregroundStyle(status.isError ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: send) {
                Text(feedback.draft.destination.actionTitle).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .help("\(feedback.draft.destination.actionTitle) (⇧⌘↩)")
            Button(action: copyText) { Text("Copy Text").frame(maxWidth: .infinity) }
                .help("Copy the feedback as Markdown")
        }
        .padding(16)
        .frame(width: 300)
        .onChange(of: feedback.draft.destination) { feedback.status = nil }
    }

    private var contextLine: String? {
        let context = feedback.draft.context
        let parts = [context.appName, context.windowTitle].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : "From " + parts.joined(separator: " — ")
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.callout).foregroundStyle(.secondary)
            content().textFieldStyle(.roundedBorder)
        }
    }
}
