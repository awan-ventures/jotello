import Foundation

/// Keeps each sent capture in its own local folder: screenshot.png, feedback.json and prompt.md.
struct CaptureStore {
    let root: URL

    static var standard: CaptureStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return CaptureStore(root: support.appendingPathComponent("Jotello/Captures", isDirectory: true))
    }

    /// Writes the bundle and returns the draft with its absolute screenshot path filled in.
    func save(png: Data, draft: FeedbackDraft) throws -> FeedbackDraft {
        let folder = root.appendingPathComponent(Self.folderName(for: draft), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let imageURL = folder.appendingPathComponent("screenshot.png")
        try png.write(to: imageURL, options: .atomic)
        var saved = draft
        saved.screenshotPath = imageURL.path
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(saved).write(to: folder.appendingPathComponent("feedback.json"), options: .atomic)
        try Data(FeedbackFormatter.agentPrompt(saved, screenshotPath: imageURL.path).utf8)
            .write(to: folder.appendingPathComponent("prompt.md"), options: .atomic)
        return saved
    }

    static func folderName(for draft: FeedbackDraft) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let slug = draft.resolvedTitle.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.prefix(6).joined(separator: "-")
        let stamp = formatter.string(from: draft.createdAt)
        return slug.isEmpty ? stamp : "\(stamp)-\(slug)"
    }
}
