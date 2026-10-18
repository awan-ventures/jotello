import AppKit

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select, arrow, line, rectangle, ellipse, text

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        }
    }
}

struct Annotation: Identifiable, Equatable {
    var id = UUID()
    var tool: AnnotationTool
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var strokeWidth: CGFloat
    var fontSize: CGFloat
    var text = ""

    var attributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium), .foregroundColor: color]
    }

    var bounds: CGRect {
        if tool == .text {
            let size = ((text.isEmpty ? " " : text) as NSString).size(withAttributes: attributes)
            return CGRect(origin: start, size: CGSize(width: max(size.width, fontSize),
                                                      height: max(size.height, fontSize * 1.2)))
        }
        return CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                      width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    var handles: [CGPoint] {
        if tool == .line || tool == .arrow { return [start, end] }
        let rect = bounds
        return [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    func contains(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        if tool == .text { return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) }
        let path = shapePath()
        if tool == .rectangle || tool == .ellipse, path.contains(point) { return true }
        return path.copy(strokingWithWidth: max(strokeWidth, tolerance * 2), lineCap: .round,
                         lineJoin: .round, miterLimit: 10).contains(point)
    }

    func shapePath() -> CGPath {
        let path = CGMutablePath()
        switch tool {
        case .line, .arrow:
            path.move(to: start)
            path.addLine(to: end)
            if tool == .arrow {
                let angle = atan2(end.y - start.y, end.x - start.x)
                let length = min(max(strokeWidth * 4, 12), hypot(end.x - start.x, end.y - start.y) * 0.45)
                for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                    path.move(to: end)
                    path.addLine(to: CGPoint(x: end.x - length * cos(angle + offset),
                                            y: end.y - length * sin(angle + offset)))
                }
            }
        case .rectangle: path.addRect(bounds)
        case .ellipse: path.addEllipse(in: bounds)
        case .text, .select: break
        }
        return path
    }

    func moved(by delta: CGSize, within size: CGSize) -> Annotation {
        var result = self
        let rect = bounds
        let dx = min(max(delta.width, min(-rect.minX, size.width - rect.maxX)),
                     max(-rect.minX, size.width - rect.maxX))
        let dy = min(max(delta.height, min(-rect.minY, size.height - rect.maxY)),
                     max(-rect.minY, size.height - rect.maxY))
        result.start.x += dx
        result.start.y += dy
        result.end.x += dx
        result.end.y += dy
        return result
    }

    func resized(handle: Int, to point: CGPoint) -> Annotation {
        var result = self
        if tool == .line || tool == .arrow {
            if handle == 0 { result.start = point } else { result.end = point }
        } else if tool == .text {
            let opposite = handles[(handle + 2) % 4]
            let originalDistance = hypot(handles[handle].x - opposite.x, handles[handle].y - opposite.y)
            let distance = hypot(point.x - opposite.x, point.y - opposite.y)
            result.fontSize = min(200, max(8, fontSize * distance / max(1, originalDistance)))
            let newSize = result.bounds.size
            result.start = CGPoint(x: handle == 0 || handle == 3 ? opposite.x - newSize.width : opposite.x,
                                   y: handle == 0 || handle == 1 ? opposite.y - newSize.height : opposite.y)
        } else {
            result.start = handles[(handle + 2) % 4]
            result.end = point
        }
        return result
    }
}
