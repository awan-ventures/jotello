import AppKit
import SwiftUI

struct AnnotationCanvas: NSViewRepresentable {
    let document: AnnotationDocument

    func makeNSView(context: Context) -> AnnotationCanvasView {
        AnnotationCanvasView(document: document)
    }

    func updateNSView(_ view: AnnotationCanvasView, context: Context) {
        // Register the model reads with SwiftUI's Observation tracking.
        _ = document.annotations
        _ = document.selectedID
        _ = document.tool
        view.needsDisplay = true
        view.window?.invalidateCursorRects(for: view)
    }
}

@MainActor
final class AnnotationCanvasView: NSView {
    enum Drag { case drawing, moving, resizing(Int) }

    let document: AnnotationDocument
    var drag: Drag?
    var dragStart = CGPoint.zero
    var originalAnnotation: Annotation?
    var textView: CanvasTextView?
    var editingID: UUID?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    var scale: CGFloat {
        max(0.001, min(bounds.width / document.pointSize.width, bounds.height / document.pointSize.height))
    }

    var imageOrigin: CGPoint {
        CGPoint(x: (bounds.width - document.pointSize.width * scale) / 2,
                y: (bounds.height - document.pointSize.height * scale) / 2)
    }

    init(document: AnnotationDocument) {
        self.document = document
        super.init(frame: .zero)
        document.commitEditing = { [weak self] in self?.finishTextEditing() }
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Screenshot annotation canvas")
        setAccessibilityHelp("Choose a drawing tool, then drag on the screenshot. Select annotations to move or resize. Double-click text to edit.")
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowResigned),
                                                   name: NSWindow.didResignKeyNotification, object: window)
        }
    }

    @objc private func windowResigned() {
        if drag != nil { cancelGesture() }
    }

    override func layout() {
        super.layout()
        updateTextFrame()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: document.tool == .select ? .arrow : document.tool == .text ? .iBeam : .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        context.saveGState()
        context.translateBy(x: imageOrigin.x, y: imageOrigin.y)
        context.scaleBy(x: scale, y: scale)
        AnnotationRenderer.draw(image: document.image, pointSize: document.pointSize,
                                annotations: document.annotations, in: context, excluding: editingID)
        if let selected = document.selectedAnnotation, editingID == nil {
            drawSelection(selected, in: context)
        }
        context.restoreGState()
    }

    private func drawSelection(_ annotation: Annotation, in context: CGContext) {
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1 / scale)
        context.setLineDash(phase: 0, lengths: [4 / scale, 3 / scale])
        context.stroke(annotation.bounds.insetBy(dx: -3 / scale, dy: -3 / scale))
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(NSColor.white.cgColor)
        for point in annotation.handles {
            let rect = CGRect(x: point.x - 4 / scale, y: point.y - 4 / scale, width: 8 / scale, height: 8 / scale)
            context.fill(rect)
            context.stroke(rect)
        }
    }

    func imagePoint(for event: NSEvent, clamped: Bool = true) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        let imagePoint = CGPoint(x: (point.x - imageOrigin.x) / scale, y: (point.y - imageOrigin.y) / scale)
        guard clamped else { return imagePoint }
        return CGPoint(x: min(max(0, imagePoint.x), document.pointSize.width),
                       y: min(max(0, imagePoint.y), document.pointSize.height))
    }

    override func mouseDown(with event: NSEvent) { beginGesture(event) }
    override func mouseDragged(with event: NSEvent) { updateGesture(event) }
    override func mouseUp(with event: NSEvent) { endGesture(event) }

    @objc func undo(_ sender: Any?) { document.undo(); needsDisplay = true }
    @objc func redo(_ sender: Any?) { document.redo(); needsDisplay = true }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "z" {
            if event.modifierFlags.contains(.shift) { document.redo() } else { document.undo() }
        } else if event.keyCode == 51 || event.keyCode == 117 {
            document.deleteSelection()
        } else if event.keyCode == 53 {
            if drag != nil { cancelGesture() } else { document.select(nil) }
        } else {
            super.keyDown(with: event)
        }
        needsDisplay = true
    }
}
