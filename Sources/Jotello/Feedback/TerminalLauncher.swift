import Foundation

enum AgentCLI: String {
    case claude, codex

    var name: String { self == .claude ? "Claude Code" : "Codex" }

    var invocation: String {
        switch self {
        // --add-dir lets Claude Code read the screenshot outside the project without asking.
        case .claude: #"claude --add-dir "$JOTELLO_CAPTURE" "$(cat "$JOTELLO_PROMPT")""#
        // Codex attaches the image itself; "--" keeps the prompt from being read as another image.
        case .codex: #"codex --image="$JOTELLO_IMAGE" -- "$(cat "$JOTELLO_PROMPT")""#
        }
    }
}

/// Something Jotello hands to the user's own terminal.
enum TerminalCommand: Equatable {
    case agent(AgentCLI, project: URL)
    /// `gh issue create` in "owner/repo".
    case githubIssue(repo: String)
    /// `gh pr comment` or `gh issue comment` on a number in "owner/repo".
    case githubComment(repo: String, isPullRequest: Bool, number: Int)
}

/// Runs a command through a Terminal `.command` file in the user's interactive login shell,
/// so their PATH and `gh auth` apply. Opening the file is an explicit user action, and
/// GitHub posts wait for a typed confirmation. All user text arrives through single-quoted
/// environment variables, so it never becomes shell code.
enum TerminalLauncher {
    struct Files {
        let folder: URL
        let image: URL
        let prompt: URL
        let body: URL
    }

    static func script(_ command: TerminalCommand, files: Files, title: String) -> String {
        var env: [(String, String)] = [("JOTELLO_CAPTURE", files.folder.path), ("JOTELLO_IMAGE", files.image.path),
                                       ("JOTELLO_PROMPT", files.prompt.path), ("JOTELLO_BODY", files.body.path),
                                       ("JOTELLO_TITLE", title)]
        let directory: String
        let shellCommand: String
        switch command {
        case .agent(let agent, let project):
            directory = project.path
            shellCommand = "if command -v \(agent.rawValue) >/dev/null 2>&1; then \(agent.invocation); "
                + "else echo; echo \"\(agent.name) (\(agent.rawValue)) was not found on your PATH. "
                + "The prompt is on your clipboard.\"; fi"
        case .githubIssue(let repo):
            directory = files.folder.path
            env.append(("JOTELLO_REPO", repo))
            shellCommand = ghConfirmed(
                question: "Create this issue in $JOTELLO_REPO?", preview: #"echo "Title: $JOTELLO_TITLE"; echo; "#,
                post: #"gh issue create --repo "$JOTELLO_REPO" --title "$JOTELLO_TITLE" --body-file "$JOTELLO_BODY""#)
        case .githubComment(let repo, let isPullRequest, let number):
            directory = files.folder.path
            env += [("JOTELLO_REPO", repo), ("JOTELLO_NUMBER", String(number))]
            let kind = isPullRequest ? "pr" : "issue"
            shellCommand = ghConfirmed(
                question: "Comment on \(kind) #$JOTELLO_NUMBER in $JOTELLO_REPO?", preview: "",
                post: "gh \(kind) comment \"$JOTELLO_NUMBER\" --repo \"$JOTELLO_REPO\" --body-file \"$JOTELLO_BODY\"")
        }
        let exports = env.map { "export \($0.0)=\(quoted($0.1))" }.joined(separator: "\n")
        return """
        #!/bin/zsh
        # Written by Jotello for one piece of feedback. Safe to delete.
        \(exports)
        case "${SHELL:-}" in */zsh|*/bash) JOTELLO_SHELL="$SHELL" ;; *) JOTELLO_SHELL=/bin/zsh ;; esac
        export JOTELLO_SHELL
        cd \(quoted(directory)) || exit 1
        exec "$JOTELLO_SHELL" -lic \(quoted(shellCommand + "; exec \"$JOTELLO_SHELL\" -l"))

        """
    }

    /// Shows the post, asks before running `gh`, then opens the result so the screenshot can be pasted.
    private static func ghConfirmed(question: String, preview: String, post: String) -> String {
        "if ! command -v gh >/dev/null 2>&1; then echo \"GitHub CLI (gh) was not found on your PATH. "
            + "Install it from https://cli.github.com and run gh auth login.\"; else "
            + preview + #"cat "$JOTELLO_BODY"; echo; echo; printf "%s [y/N] " ""# + question + "\"; read answer; "
            + "case \"$answer\" in [yY]*) if out=$(" + post + "); then url=$(printf '%s\\n' \"$out\" | tail -n 1); "
            + "echo \"$url\"; open \"$url\"; "
            + "echo \"Opened in your browser. The screenshot is on your clipboard: paste it in a comment.\"; fi ;; "
            + "*) echo \"Nothing was posted.\" ;; esac; fi"
    }

    /// Writes an executable launcher next to the capture and returns its URL.
    static func writeScript(_ command: TerminalCommand, screenshot: URL, title: String, body: String) throws -> URL {
        let folder = screenshot.deletingLastPathComponent()
        let files = Files(folder: folder, image: screenshot, prompt: folder.appendingPathComponent("prompt.md"),
                          body: folder.appendingPathComponent("github.md"))
        try Data(body.utf8).write(to: files.body, options: .atomic)
        let name: String
        switch command {
        case .agent(let agent, _): name = "open-in-\(agent.rawValue)"
        case .githubIssue, .githubComment: name = "post-with-gh"
        }
        let url = folder.appendingPathComponent("\(name).command")
        try Data(script(command, files: files, title: title).utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    /// Single-quotes a string for the shell.
    static func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
