import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let annotationDocument: AnnotationDocument
    let feedback: FeedbackModel
    private let store: CaptureStore
    var onClose: (() -> Void)?

    var hasUnsavedWork: Bool { annotationDocument.hasUnsavedChanges || feedback.hasUnsentText }

    init(capture: CapturedImage, store: CaptureStore = .standard) {
        annotationDocument = AnnotationDocument(image: capture.image, pointSize: capture.pointSize)
        feedback = FeedbackModel(context: CaptureContext(appName: capture.appName, windowTitle: capture.windowTitle,
                                                         pixelWidth: capture.image.width,
                                                         pixelHeight: capture.image.height))
        self.store = store
        let visibleSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1200, height: 900)
        let size = NSSize(width: min(1280, visibleSize.width - 80), height: min(780, visibleSize.height - 80))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Jotello"
        window.minSize = NSSize(width: 980, height: 560)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView(
            document: annotationDocument, feedback: feedback,
            copy: { [weak self] in self?.copyImage() ?? false },
            save: { [weak self] in self?.saveImage() },
            send: { [weak self] in self?.send() },
            copyText: { [weak self] in self?.copyText() }))
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        annotationDocument.commitEditing?()
        guard hasUnsavedWork else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard this feedback?"
        alert.informativeText = "Send, copy or save it to keep your latest changes."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func windowWillClose(_ notification: Notification) {
        // Defer removal so the controller survives the delegate callback.
        Task { @MainActor [weak self] in self?.onClose?() }
    }

    private func pngData() throws -> Data {
        guard let image = annotationDocument.renderedImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ExportError.renderFailed
        }
        return data
    }

    @discardableResult
    private func copyImage() -> Bool {
        do {
            let data = try pngData()
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setData(data, forType: .png) else { throw ExportError.clipboardFailed }
            annotationDocument.markExported()
            return true
        } catch {
            showError(error)
            return false
        }
    }

    private func send() {
        do {
            let handoff = try FeedbackHandoff.prepare(draft: feedback.draft, png: try pngData(), store: store)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            switch handoff.clipboard {
            case .text(let text): pasteboard.setString(text, forType: .string)
            case .image: pasteboard.setData(try pngData(), forType: .png)
            }
            if let url = handoff.url { NSWorkspace.shared.open(url) }
            feedback.markSent(handoff.draft)
            annotationDocument.markExported()
            feedback.status = .init(message: handoff.message, isError: false)
        } catch {
            feedback.status = .init(message: error.localizedDescription, isError: true)
        }
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(FeedbackFormatter.markdown(feedback.draft), forType: .string)
        feedback.markCopied()
        feedback.status = .init(message: "Copied the feedback as Markdown.", isError: false)
    }

    private func saveImage() {
        guard let window else { return }
        do {
            let data = try pngData()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.canCreateDirectories = true
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            panel.nameFieldStringValue = "Jotello \(formatter.string(from: Date())).png"
            panel.beginSheetModal(for: window) { [weak self] response in
                guard response == .OK, let url = panel.url, let self else { return }
                do {
                    try data.write(to: url, options: .atomic)
                    annotationDocument.markExported()
                } catch { showError(error) }
            }
        } catch { showError(error) }
    }

    private func showError(_ error: Error) {
        guard let window else { return }
        NSAlert(error: error).beginSheetModal(for: window)
    }
}

private enum ExportError: LocalizedError {
    case renderFailed, clipboardFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: "The screenshot couldn’t be rendered. Your annotations are still here; please try again."
        case .clipboardFailed: "The clipboard couldn’t be updated. Please try again or save a PNG."
        }
    }
}
