import Foundation

enum Destination: String, CaseIterable, Codable, Identifiable {
    // "agent" is the generic clipboard destination; the raw value predates the named agents.
    case claudeCode, codex, githubIssue, githubComment, agent

    var id: String { rawValue }
    var title: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .githubIssue: "New GitHub issue"
        case .githubComment: "GitHub PR or issue comment"
        case .agent: "Clipboard (any agent)"
        }
    }
    var isGitHub: Bool { self == .githubIssue || self == .githubComment }
    var agent: AgentCLI? {
        switch self {
        case .claudeCode: .claude
        case .codex: .codex
        default: nil
        }
    }

    /// The button label, which depends on the project folder and the GitHub CLI choice.
    func actionTitle(for draft: FeedbackDraft) -> String {
        let hasFolder = !draft.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch self {
        case .claudeCode, .codex: return hasFolder ? "Open in \(title)" : "Copy for \(title)"
        case .githubIssue: return draft.useGitHubCLI ? "Create with gh…" : "Open Issue"
        case .githubComment: return draft.useGitHubCLI ? "Comment with gh…" : "Open and Copy Comment"
        case .agent: return "Copy Prompt"
        }
    }
    var targetLabel: String? {
        switch self {
        case .claudeCode, .codex: "Project folder (optional)"
        case .githubIssue: "Repository URL"
        case .githubComment: "Pull request or issue URL"
        case .agent: nil
        }
    }
    var targetPlaceholder: String {
        switch self {
        case .claudeCode, .codex: "~/Code/my-app"
        case .githubComment: "https://github.com/owner/repo/pull/123"
        default: "https://github.com/owner/repo"
        }
    }
}

/// A repository, issue or pull request on github.com, parsed from a pasted URL.
struct GitHubTarget: Equatable {
    let owner: String
    let repo: String
    /// "pull" or "issues" when the URL points at a conversation.
    let kind: String?
    let number: Int?

    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), let host = url.host?.lowercased(),
              host == "github.com" || host == "www.github.com" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        owner = parts[0]
        repo = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
        if parts.count >= 4, ["pull", "issues"].contains(parts[2]), let value = Int(parts[3]) {
            kind = parts[2]
            number = value
        } else {
            kind = nil
            number = nil
        }
        guard !owner.isEmpty, !repo.isEmpty else { return nil }
    }

    var repositoryURL: URL { URL(string: "https://github.com/\(owner)/\(repo)")! }
    var fullName: String { "\(owner)/\(repo)" }

    var conversationURL: URL? {
        guard let kind, let number else { return nil }
        return repositoryURL.appendingPathComponent("\(kind)/\(number)")
    }
}

enum DestinationError: LocalizedError, Equatable {
    case missingRepository, missingConversation, missingFolder(String)

    var errorDescription: String? {
        switch self {
        case .missingRepository: "Enter a GitHub repository URL, like https://github.com/owner/repo."
        case .missingConversation: "Enter a GitHub pull request or issue URL, like https://github.com/owner/repo/pull/123."
        case .missingFolder(let path): "The project folder \(path) doesn’t exist. Choose another or leave it empty."
        }
    }
}

enum DestinationAdapter {
    /// The agent's project folder, or nil when none is set. Throws when it doesn't exist.
    static func projectFolder(for draft: FeedbackDraft) throws -> URL? {
        guard draft.destination.agent != nil else { return nil }
        let path = draft.target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DestinationError.missingFolder(path)
        }
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    /// GitHub documents the `title` and `body` query parameters for new issues.
    /// Long bodies are left out; the report is on the clipboard either way.
    static let maxBodyLength = 6000

    /// The page to open in the user's browser, or nil for the agent and clipboard destinations.
    static func url(for draft: FeedbackDraft) throws -> URL? {
        switch draft.destination {
        case .agent, .claudeCode, .codex:
            return nil
        case .githubIssue:
            guard let target = GitHubTarget(draft.target) else { throw DestinationError.missingRepository }
            var items = [URLQueryItem(name: "title", value: draft.resolvedTitle)]
            let body = FeedbackFormatter.issueBody(draft)
            if body.count <= maxBodyLength { items.append(URLQueryItem(name: "body", value: body)) }
            var components = URLComponents(url: target.repositoryURL.appendingPathComponent("issues/new"),
                                           resolvingAgainstBaseURL: false)!
            components.queryItems = items
            // URLComponents leaves "+" alone, which servers read as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
            return components.url
        case .githubComment:
            guard let url = GitHubTarget(draft.target)?.conversationURL else {
                throw DestinationError.missingConversation
            }
            return url
        }
    }
}
