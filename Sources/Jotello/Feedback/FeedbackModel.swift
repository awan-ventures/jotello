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
        draft.targetURL = defaults.string(forKey: Keys.targetURL) ?? ""
        self.draft = draft
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
        defaults.set(draft.targetURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.targetURL)
    }

    func markCopied() { sentDraft = draft }

    private enum Keys {
        static let destination = "lastDestination"
        static let targetURL = "lastTargetURL"
    }
}
