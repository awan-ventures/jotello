import AppKit
import Observation

@MainActor @Observable
final class AnnotationDocument {
    let image: CGImage
    let pointSize: CGSize
    var tool: AnnotationTool = .arrow
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 3
    var fontSize: CGFloat = 24
    var selectedID: UUID?
    private(set) var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private var exportedAnnotations: [Annotation] = []
    @ObservationIgnored private var transaction: [Annotation]?
    @ObservationIgnored var commitEditing: (() -> Void)?

    init(image: CGImage, pointSize: CGSize) {
        self.image = image
        self.pointSize = CGSize(width: max(1, pointSize.width), height: max(1, pointSize.height))
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var hasUnsavedChanges: Bool { annotations != exportedAnnotations }
    var selectedAnnotation: Annotation? { annotations.first { $0.id == selectedID } }

    func markExported() { exportedAnnotations = annotations }

    func setTool(_ value: AnnotationTool) {
        commitEditing?()
        commitTransaction()
        tool = value
    }

    func select(_ id: UUID?) {
        selectedID = id
        if let annotation = selectedAnnotation {
            color = annotation.color
            strokeWidth = annotation.strokeWidth
            fontSize = annotation.fontSize
        }
    }

    func setColor(_ value: NSColor) {
        changeStyle { color = value; updateSelected { $0.color = value } }
    }

    func setStrokeWidth(_ value: CGFloat) {
        guard value.isFinite else { return }
        changeStyle {
            strokeWidth = min(30, max(1, value))
            updateSelected { $0.strokeWidth = strokeWidth }
        }
    }

    func setFontSize(_ value: CGFloat) {
        guard value.isFinite else { return }
        changeStyle {
            fontSize = min(200, max(8, value))
            updateSelected { $0.fontSize = fontSize }
        }
    }

    func beginStyleChange() { commitEditing?(); beginTransaction() }
    func finishStyleChange() { commitTransaction() }

    private func changeStyle(_ change: () -> Void) {
        commitEditing?()
        let isStandalone = transaction == nil
        if isStandalone { beginTransaction() }
        change()
        if isStandalone { commitTransaction() }
    }

    private func updateSelected(_ change: (inout Annotation) -> Void) {
        guard let index = annotations.firstIndex(where: { $0.id == selectedID }) else { return }
        change(&annotations[index])
    }

    func makeAnnotation(at point: CGPoint) -> Annotation {
        Annotation(tool: tool, start: point, end: point, color: color,
                   strokeWidth: strokeWidth, fontSize: fontSize)
    }

    func beginTransaction() {
        if transaction == nil { transaction = annotations }
    }

    func update(_ annotation: Annotation) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[index] = annotation
        } else {
            annotations.append(annotation)
        }
    }

    func remove(_ id: UUID) { annotations.removeAll { $0.id == id } }

    func commitTransaction() {
        guard let before = transaction else { return }
        transaction = nil
        guard before != annotations else { return }
        undoStack.append(before)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func cancelTransaction() {
        guard let before = transaction else { return }
        annotations = before
        transaction = nil
        select(selectedAnnotation == nil ? nil : selectedID)
    }

    func undo() {
        commitEditing?()
        commitTransaction()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        select(nil)
    }

    func redo() {
        commitEditing?()
        commitTransaction()
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        select(nil)
    }

    func deleteSelection() {
        commitEditing?()
        guard let selectedID else { return }
        beginTransaction()
        remove(selectedID)
        select(nil)
        commitTransaction()
    }

    func renderedImage() -> CGImage? {
        commitEditing?()
        return AnnotationRenderer.render(image: image, pointSize: pointSize, annotations: annotations)
    }
}
