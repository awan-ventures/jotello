import AppKit

extension AnnotationCanvasView {
    func beginGesture(_ event: NSEvent) {
        finishTextEditing()
        window?.makeFirstResponder(self)
        let point = imagePoint(for: event, clamped: false)
        guard CGRect(origin: .zero, size: document.pointSize).contains(point) else { return }
        dragStart = point

        if document.tool == .select {
            if event.clickCount == 2,
               let text = document.annotations.reversed().first(where: { $0.tool == .text && $0.contains(point, tolerance: 2 / scale) }) {
                beginTextEditing(text, isNew: false)
                return
            }
            if let selected = document.selectedAnnotation,
               let handle = selected.handles.firstIndex(where: { hypot($0.x - point.x, $0.y - point.y) < 8 / scale }) {
                originalAnnotation = selected
                drag = .resizing(handle)
                document.beginTransaction()
                return
            }
            let hit = document.annotations.reversed().first { $0.contains(point, tolerance: 6 / scale) }
            document.select(hit?.id)
            guard let hit else { needsDisplay = true; return }
            originalAnnotation = hit
            drag = .moving
        } else if document.tool == .text {
            let hit = document.annotations.reversed().first { $0.tool == .text && $0.contains(point, tolerance: 2 / scale) }
            beginTextEditing(hit ?? document.makeAnnotation(at: point), isNew: hit == nil)
            return
        } else {
            document.beginTransaction()
            let annotation = document.makeAnnotation(at: point)
            originalAnnotation = annotation
            document.update(annotation)
            document.select(annotation.id)
            drag = .drawing
        }
        document.beginTransaction()
        needsDisplay = true
    }

    func updateGesture(_ event: NSEvent) {
        guard let drag, let original = originalAnnotation else { return }
        var point = imagePoint(for: event)
        let result: Annotation
        switch drag {
        case .drawing:
            if event.modifierFlags.contains(.shift) { point = constrained(point, for: original) }
            var annotation = original
            annotation.end = point
            result = annotation
        case .moving:
            result = original.moved(by: CGSize(width: point.x - dragStart.x, height: point.y - dragStart.y),
                                    within: document.pointSize)
        case .resizing(let handle):
            result = original.resized(handle: handle, to: point).moved(by: .zero, within: document.pointSize)
        }
        document.update(result)
        if result.tool == .text { document.fontSize = result.fontSize }
        needsDisplay = true
    }

    func endGesture(_ event: NSEvent) {
        guard let drag else { return }
        updateGesture(event)
        if case .drawing = drag, let selected = document.selectedAnnotation {
            let tooSmall: Bool
            if selected.tool == .line || selected.tool == .arrow {
                tooSmall = hypot(selected.end.x - selected.start.x, selected.end.y - selected.start.y) < 2
            } else {
                tooSmall = selected.bounds.width < 2 || selected.bounds.height < 2
            }
            if tooSmall { document.cancelTransaction() }
        }
        document.commitTransaction()
        self.drag = nil
        originalAnnotation = nil
        needsDisplay = true
    }

    func cancelGesture() {
        document.cancelTransaction()
        drag = nil
        originalAnnotation = nil
        needsDisplay = true
    }

    private func constrained(_ point: CGPoint, for annotation: Annotation) -> CGPoint {
        let dx = point.x - annotation.start.x
        let dy = point.y - annotation.start.y
        let result: CGPoint
        if annotation.tool == .rectangle || annotation.tool == .ellipse {
            let length = min(abs(dx), abs(dy))
            result = CGPoint(x: annotation.start.x + (dx < 0 ? -length : length),
                             y: annotation.start.y + (dy < 0 ? -length : length))
        } else {
            let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
            let length = hypot(dx, dy)
            result = CGPoint(x: annotation.start.x + length * cos(angle), y: annotation.start.y + length * sin(angle))
        }
        return CGPoint(x: min(max(0, result.x), document.pointSize.width),
                       y: min(max(0, result.y), document.pointSize.height))
    }
}
