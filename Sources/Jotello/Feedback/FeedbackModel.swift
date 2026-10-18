import Foundation
import Observation

@MainActor @Observable
final class FeedbackModel {
    struct Status: Equatable {
        let message: String
        let isError: Bool
    }

    var draft: FeedbackDraft
    var status: Status?
    private var sentDraft: FeedbackDraft?
    @ObservationIgnored private let defaults: UserDefaults

    init(context: CaptureContext, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var draft = FeedbackDraft(context: context)
        if let value = defaults.string(forKey: Keys.destination), let destination = Destination(rawValue: value) {
            draft.destination = destination
        }
        draft.target = defaults.string(forKey: Keys.target(draft.destination)) ?? ""
        draft.useGitHubCLI = defaults.bool(forKey: Keys.useGitHubCLI)
        self.draft = draft
    }

    /// Switches destination and restores the URL or folder last used with it.
    func setDestination(_ destination: Destination) {
        guard destination != draft.destination else { return }
        draft.destination = destination
        draft.target = defaults.string(forKey: Keys.target(destination)) ?? ""
        status = nil
    }

    /// Typed feedback that hasn't been sent or copied yet.
    var hasUnsentText: Bool {
        let typed = !draft.trimmedDescription.isEmpty || !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
        return typed && draft != sentDraft
    }

    /// Records a successful handoff and remembers the destination for the next capture.
    func markSent(_ saved: FeedbackDraft) {
        draft.screenshotPath = saved.screenshotPath
        sentDraft = draft
        defaults.set(draft.destination.rawValue, forKey: Keys.destination)
        defaults.set(draft.target.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.target(draft.destination))
        if draft.destination.isGitHub { defaults.set(draft.useGitHubCLI, forKey: Keys.useGitHubCLI) }
    }

    func markCopied() { sentDraft = draft }

    private enum Keys {
        static let destination = "lastDestination"
        static let useGitHubCLI = "useGitHubCLI"
        static func target(_ destination: Destination) -> String { "lastTarget.\(destination.rawValue)" }
    }
}
