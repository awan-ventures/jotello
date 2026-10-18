import Foundation

enum Destination: String, CaseIterable, Codable, Identifiable {
    case agent, githubIssue, githubComment

    var id: String { rawValue }
    var title: String {
        switch self {
        case .agent: "Agent or clipboard"
        case .githubIssue: "New GitHub issue"
        case .githubComment: "GitHub PR or issue comment"
        }
    }
    var actionTitle: String {
        switch self {
        case .agent: "Copy for Agent"
        case .githubIssue: "Open Issue"
        case .githubComment: "Open and Copy Comment"
        }
    }
    var targetLabel: String? {
        switch self {
        case .agent: nil
        case .githubIssue: "Repository URL"
        case .githubComment: "Pull request or issue URL"
        }
    }
    var targetPlaceholder: String {
        self == .githubComment ? "https://github.com/owner/repo/pull/123" : "https://github.com/owner/repo"
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

    var conversationURL: URL? {
        guard let kind, let number else { return nil }
        return repositoryURL.appendingPathComponent("\(kind)/\(number)")
    }
}

enum DestinationError: LocalizedError, Equatable {
    case missingRepository, missingConversation

    var errorDescription: String? {
        switch self {
        case .missingRepository: "Enter a GitHub repository URL, like https://github.com/owner/repo."
        case .missingConversation: "Enter a GitHub pull request or issue URL, like https://github.com/owner/repo/pull/123."
        }
    }
}

enum DestinationAdapter {
    /// GitHub documents the `title` and `body` query parameters for new issues.
    /// Long bodies are left out; the report is on the clipboard either way.
    static let maxBodyLength = 6000

    /// The page to open in the user's browser, or nil when the destination is clipboard-only.
    static func url(for draft: FeedbackDraft) throws -> URL? {
        switch draft.destination {
        case .agent:
            return nil
        case .githubIssue:
            guard let target = GitHubTarget(draft.targetURL) else { throw DestinationError.missingRepository }
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
            guard let url = GitHubTarget(draft.targetURL)?.conversationURL else {
                throw DestinationError.missingConversation
            }
            return url
        }
    }
}
