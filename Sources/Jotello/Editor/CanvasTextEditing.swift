import AppKit

extension AnnotationCanvasView: NSTextViewDelegate {
    func beginTextEditing(_ annotation: Annotation, isNew: Bool) {
        document.beginTransaction()
        if isNew { document.update(annotation) }
        document.select(annotation.id)
        editingID = annotation.id

        let editor = CanvasTextView(frame: .zero)
        editor.string = annotation.text
        editor.isRichText = false
        editor.importsGraphics = false
        editor.drawsBackground = false
        editor.textContainerInset = .zero
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.widthTracksTextView = false
        editor.textContainer?.containerSize = CGSize(width: 100_000, height: 100_000)
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = false
        editor.allowsUndo = true
        editor.delegate = self
        editor.setAccessibilityLabel("Annotation text")
        editor.onCommit = { [weak self] in self?.finishTextEditing() }
        editor.onCancel = { [weak self] in self?.finishTextEditing(cancel: true) }
        textView = editor
        addSubview(editor)
        updateTextFrame()
        window?.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        needsDisplay = true
    }

    func textDidChange(_ notification: Notification) {
        guard let editor = textView, let id = editingID,
              var annotation = document.annotations.first(where: { $0.id == id }) else { return }
        annotation.text = editor.string
        document.update(annotation)
        updateTextFrame()
    }

    func updateTextFrame() {
        guard let editor = textView, let id = editingID,
              let annotation = document.annotations.first(where: { $0.id == id }) else { return }
        let origin = CGPoint(x: imageOrigin.x + annotation.start.x * scale,
                             y: imageOrigin.y + annotation.start.y * scale)
        let availableWidth = max(1, (document.pointSize.width - annotation.start.x) * scale)
        let availableHeight = max(1, (document.pointSize.height - annotation.start.y) * scale)
        editor.frame = CGRect(origin: origin,
                              size: CGSize(width: min(availableWidth, max(220 * scale, annotation.bounds.width * scale + 16)),
                                           height: min(availableHeight, max(annotation.fontSize * 1.6 * scale,
                                                                          annotation.bounds.height * scale + 8))))
        let font = NSFont.systemFont(ofSize: annotation.fontSize * scale, weight: .medium)
        if editor.font != font { editor.font = font }
        if editor.textColor != annotation.color { editor.textColor = annotation.color }
        editor.insertionPointColor = annotation.color
    }

    func finishTextEditing(cancel: Bool = false) {
        guard let editor = textView, let id = editingID else { return }
        editor.unmarkText()
        if cancel {
            document.cancelTransaction()
        } else {
            if var annotation = document.annotations.first(where: { $0.id == id }) {
                annotation.text = editor.string
                if annotation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    document.remove(id)
                    document.select(nil)
                } else {
                    document.update(annotation)
                }
            }
            document.commitTransaction()
        }
        editor.delegate = nil
        editor.removeFromSuperview()
        textView = nil
        editingID = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }
}

final class CanvasTextView: NSTextView {
    private let textUndoManager = UndoManager()
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    override var undoManager: UndoManager? { textUndoManager }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36, event.modifierFlags.contains(.command) {
            onCommit?()
        } else if event.keyCode == 53, !hasMarkedText() {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
