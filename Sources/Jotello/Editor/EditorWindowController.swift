import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let annotationDocument: AnnotationDocument
    var onClose: (() -> Void)?

    init(image: CGImage, pointSize: CGSize) {
        annotationDocument = AnnotationDocument(image: image, pointSize: pointSize)
        let visibleSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1200, height: 900)
        let size = NSSize(width: min(1040, visibleSize.width - 80), height: min(760, visibleSize.height - 80))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Jotello"
        window.minSize = NSSize(width: 740, height: 440)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView(document: annotationDocument, copy: { [weak self] in
            self?.copyImage() ?? false
        }, save: { [weak self] in self?.saveImage() }))
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        annotationDocument.commitEditing?()
        guard annotationDocument.hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard these annotations?"
        alert.informativeText = "Copy or save your screenshot to keep your latest changes."
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
