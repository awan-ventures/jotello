import Foundation

enum FeedbackCategory: String, CaseIterable, Codable, Identifiable {
    case bug, ux, polish, other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bug: "Bug"
        case .ux: "UX improvement"
        case .polish: "Polish"
        case .other: "Other"
        }
    }
}

/// What Jotello knows about the capture without reading any app's content.
struct CaptureContext: Codable, Equatable {
    var appName: String?
    var windowTitle: String?
    var pixelWidth: Int
    var pixelHeight: Int
}

/// Versioned local representation of one piece of feedback.
struct FeedbackDraft: Codable, Equatable {
    var version = 1
    var id = UUID()
    var createdAt = Date()
    var title = ""
    var description = ""
    var category: FeedbackCategory = .bug
    var sourceURL = ""
    var destination: Destination = .claudeCode
    /// A repository or conversation URL for GitHub, or a project folder for an agent.
    var target = ""
    /// Post to GitHub through the user's own `gh` login instead of a prefilled browser page.
    var useGitHubCLI = false
    var context: CaptureContext
    var screenshotPath: String?

    /// The typed title, else the first line of the description, else a generic label.
    var resolvedTitle: String {
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        let firstLine = description.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        if firstLine.isEmpty {
            return "\(category.title) feedback" + (context.appName.map { " in \($0)" } ?? "")
        }
        return firstLine.count > 72 ? String(firstLine.prefix(71)) + "…" : firstLine
    }

    var trimmedDescription: String { description.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSourceURL: String { sourceURL.trimmingCharacters(in: .whitespacesAndNewlines) }
}
