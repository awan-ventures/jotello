import Foundation

enum FeedbackFormatter {
    /// Body for a new GitHub issue. The title travels separately. Never includes local paths.
    static func issueBody(_ draft: FeedbackDraft) -> String {
        var lines = ["**\(draft.category.title)**", ""]
        if !draft.trimmedDescription.isEmpty { lines += [draft.trimmedDescription, ""] }
        lines += details(draft)
        lines += ["", "<!-- Paste the annotated screenshot here (⌘V). -->"]
        return lines.joined(separator: "\n")
    }

    /// Markdown with a heading, for comments and plain clipboard use.
    static func markdown(_ draft: FeedbackDraft) -> String {
        var lines = ["### \(draft.resolvedTitle)", "", "**\(draft.category.title)**", ""]
        if !draft.trimmedDescription.isEmpty { lines += [draft.trimmedDescription, ""] }
        lines += details(draft)
        return lines.joined(separator: "\n")
    }

    /// A task prompt for Claude Code, Codex or another terminal agent.
    /// Includes the absolute screenshot path because clipboard images don't reach every terminal.
    static func agentPrompt(_ draft: FeedbackDraft, screenshotPath: String) -> String {
        var lines = ["Please address this UI feedback.", "", "## \(draft.resolvedTitle)", "",
                     "Type: \(draft.category.title)"]
        if !draft.trimmedDescription.isEmpty { lines += ["", draft.trimmedDescription] }
        lines.append("")
        if !draft.trimmedSourceURL.isEmpty { lines.append("Page: \(draft.trimmedSourceURL)") }
        if let app = appLine(draft.context) { lines.append("Captured from: \(app)") }
        if !draft.targetURL.isEmpty, draft.destination != .agent { lines.append("Related: \(draft.targetURL)") }
        lines.append("Screenshot (\(size(draft.context))): \(screenshotPath)")
        lines += ["", "Arrows, boxes and text drawn on the screenshot mark what should change. "
                  + "Open the image before making changes."]
        return lines.joined(separator: "\n")
    }

    private static func details(_ draft: FeedbackDraft) -> [String] {
        var lines: [String] = []
        if !draft.trimmedSourceURL.isEmpty { lines.append("- Page: \(draft.trimmedSourceURL)") }
        if let app = appLine(draft.context) { lines.append("- Captured from: \(app)") }
        lines.append("- Screenshot: \(size(draft.context)), annotated with Jotello")
        return lines
    }

    private static func appLine(_ context: CaptureContext) -> String? {
        let parts = [context.appName, context.windowTitle].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " — ")
    }

    private static func size(_ context: CaptureContext) -> String {
        "\(context.pixelWidth) × \(context.pixelHeight) px"
    }
}
