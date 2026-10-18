import Foundation

/// What one send does: which clipboard content to set, what to open, and what to tell the user.
/// Jotello never posts anything itself. Browser pages are submitted by the user, and terminal
/// launches either start an agent locally or wait for a typed confirmation before `gh` posts.
struct FeedbackHandoff: Equatable {
    enum Clipboard: Equatable { case text(String), image }

    let draft: FeedbackDraft
    let clipboard: Clipboard
    /// A web page, or a `.command` file that Terminal runs.
    let url: URL?
    let message: String

    /// Validates the destination first, so nothing is written for an incomplete form.
    static func prepare(draft: FeedbackDraft, png: Data, store: CaptureStore) throws -> FeedbackHandoff {
        let webURL = try DestinationAdapter.url(for: draft)
        let project = try DestinationAdapter.projectFolder(for: draft)
        let saved = try store.save(png: png, draft: draft)
        let screenshot = URL(fileURLWithPath: saved.screenshotPath ?? "")
        let prompt = FeedbackFormatter.agentPrompt(saved, screenshotPath: screenshot.path)

        if let agent = saved.destination.agent {
            guard let project else {
                return FeedbackHandoff(draft: saved, clipboard: .text(prompt), url: nil,
                                       message: "Copied a prompt with the screenshot path. Paste it into \(agent.name).")
            }
            let script = try TerminalLauncher.writeScript(.agent(agent, project: project), screenshot: screenshot,
                                                          title: saved.resolvedTitle, body: prompt)
            return FeedbackHandoff(draft: saved, clipboard: .text(prompt), url: script,
                                   message: "Opened \(agent.name) in Terminal in \(project.lastPathComponent). "
                                       + "The prompt is also on your clipboard.")
        }

        switch saved.destination {
        case .githubIssue where saved.useGitHubCLI:
            let repo = GitHubTarget(saved.target)!.fullName
            let script = try TerminalLauncher.writeScript(.githubIssue(repo: repo), screenshot: screenshot,
                                                          title: saved.resolvedTitle,
                                                          body: FeedbackFormatter.issueBody(saved))
            return FeedbackHandoff(draft: saved, clipboard: .image, url: script,
                                   message: "Opened Terminal. Confirm there to create the issue with gh; "
                                       + "then paste (⌘V) the screenshot in a comment.")
        case .githubComment where saved.useGitHubCLI:
            let target = GitHubTarget(saved.target)!
            let script = try TerminalLauncher.writeScript(
                .githubComment(repo: target.fullName, isPullRequest: target.kind == "pull", number: target.number!),
                screenshot: screenshot, title: saved.resolvedTitle, body: FeedbackFormatter.markdown(saved))
            return FeedbackHandoff(draft: saved, clipboard: .image, url: script,
                                   message: "Opened Terminal. Confirm there to comment with gh; "
                                       + "then paste (⌘V) the screenshot in another comment.")
        case .githubIssue:
            if webURL?.query?.contains("body=") == true {
                return FeedbackHandoff(draft: saved, clipboard: .image, url: webURL,
                                       message: "Opened a new issue in your browser. Paste (⌘V) in the description "
                                           + "to attach the screenshot, then submit.")
            }
            return FeedbackHandoff(draft: saved, clipboard: .text(FeedbackFormatter.issueBody(saved)), url: webURL,
                                   message: "Opened a new issue and copied the long description. Paste it, "
                                       + "then use Copy Image to attach the screenshot.")
        case .githubComment:
            return FeedbackHandoff(draft: saved, clipboard: .text(FeedbackFormatter.markdown(saved)), url: webURL,
                                   message: "Opened the conversation and copied the comment. Paste it, "
                                       + "then use Copy Image to attach the screenshot.")
        case .agent, .claudeCode, .codex:
            return FeedbackHandoff(draft: saved, clipboard: .text(prompt), url: nil,
                                   message: "Copied a prompt with the screenshot path. Paste it into your agent "
                                       + "or terminal.")
        }
    }
}
