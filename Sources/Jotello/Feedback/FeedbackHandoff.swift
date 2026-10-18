import Foundation

/// What one send does: which clipboard content to set, which page to open, and what to tell the user.
/// Jotello never posts anything itself; the user reviews and submits in their own browser or terminal.
struct FeedbackHandoff: Equatable {
    enum Clipboard: Equatable { case text(String), image }

    let draft: FeedbackDraft
    let clipboard: Clipboard
    let url: URL?
    let message: String

    /// Validates the destination first, so nothing is written for an incomplete form.
    static func prepare(draft: FeedbackDraft, png: Data, store: CaptureStore) throws -> FeedbackHandoff {
        let url = try DestinationAdapter.url(for: draft)
        let saved = try store.save(png: png, draft: draft)
        let path = saved.screenshotPath ?? ""
        switch saved.destination {
        case .agent:
            return FeedbackHandoff(
                draft: saved, clipboard: .text(FeedbackFormatter.agentPrompt(saved, screenshotPath: path)), url: nil,
                message: "Copied a prompt with the screenshot path. Paste it into Claude Code, Codex or a terminal.")
        case .githubIssue:
            if url?.query?.contains("body=") == true {
                return FeedbackHandoff(
                    draft: saved, clipboard: .image, url: url,
                    message: "Opened a new issue in your browser. Paste (⌘V) in the description to attach "
                        + "the screenshot, then submit.")
            }
            return FeedbackHandoff(
                draft: saved, clipboard: .text(FeedbackFormatter.issueBody(saved)), url: url,
                message: "Opened a new issue and copied the long description. Paste it, then use Copy Image "
                    + "to attach the screenshot.")
        case .githubComment:
            return FeedbackHandoff(
                draft: saved, clipboard: .text(FeedbackFormatter.markdown(saved)), url: url,
                message: "Opened the conversation and copied the comment. Paste it, then use Copy Image "
                    + "to attach the screenshot.")
        }
    }
}
