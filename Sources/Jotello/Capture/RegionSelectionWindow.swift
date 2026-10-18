import AppKit

@MainActor
final class RegionSelectionWindow: NSWindow {
    init(image: CGImage, frame: NSRect, onSelection: @escaping (CGRect?) -> Void) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        let selectionView = RegionSelectionView(image: image, frame: NSRect(origin: .zero, size: frame.size))
        selectionView.onSelection = onSelection
        contentView = selectionView
        makeFirstResponder(selectionView)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class RegionSelectionView: NSView {
    var onSelection: ((CGRect?) -> Void)?
    private let image: CGImage
    private var anchor: NSPoint?
    private var selection: NSRect?

    init(image: CGImage, frame: NSRect) {
        self.image = image
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Screenshot region selection")
        setAccessibilityHelp("Drag to select a region. Press Return to capture this display, or Escape to cancel.")
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(image, in: bounds)
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.38).cgColor)
        if let selection {
            context.addRect(bounds)
            context.addRect(selection)
            context.drawPath(using: .eoFill)
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.stroke(selection.insetBy(dx: 0.5, dy: 0.5))
        } else {
            context.fill(bounds)
        }
        context.restoreGState()
        drawCaption("Drag a region  ·  Return: full screen  ·  Esc: cancel",
                    at: CGPoint(x: bounds.midX, y: 32))
        if let selection, selection.width > 1, selection.height > 1 {
            let scaleX = CGFloat(image.width) / bounds.width
            let scaleY = CGFloat(image.height) / bounds.height
            let dimensions = "\(Int((selection.width * scaleX).rounded())) × \(Int((selection.height * scaleY).rounded())) px"
            drawCaption(dimensions, at: CGPoint(x: selection.midX,
                                               y: min(bounds.maxY - 28, selection.maxY + 14)))
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        anchor = clampedPoint(event)
        selection = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        let point = clampedPoint(event)
        selection = CGRect(x: min(anchor.x, point.x), y: min(anchor.y, point.y),
                           width: abs(point.x - anchor.x), height: abs(point.y - anchor.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        anchor = nil
        guard let selection, selection.width >= 2, selection.height >= 2 else {
            self.selection = nil
            needsDisplay = true
            return
        }
        onSelection?(selection)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onSelection?(nil)
        case 36, 76: onSelection?(bounds)
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) { onSelection?(nil) }

    private func clampedPoint(_ event: NSEvent) -> NSPoint {
        let point = convert(event.locationInWindow, from: nil)
        return NSPoint(x: min(bounds.maxX, max(bounds.minX, point.x)),
                       y: min(bounds.maxY, max(bounds.minY, point.y)))
    }

    private func drawCaption(_ text: String, at center: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let x = min(max(12, center.x - size.width / 2), max(12, bounds.width - size.width - 12))
        let rect = CGRect(x: x, y: center.y, width: size.width, height: size.height)
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: -9, dy: -6), xRadius: 7, yRadius: 7).fill()
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}
