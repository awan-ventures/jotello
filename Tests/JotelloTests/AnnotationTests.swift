import AppKit
import XCTest
@testable import Jotello

final class AnnotationTests: XCTestCase {
    func testRetinaExportPreservesOrientationAndScalesAnnotations() throws {
        let image = try fixture(width: 80, height: 60, splitColors: true)
        let line = Self.annotation(.line, start: CGPoint(x: 5, y: 5), end: CGPoint(x: 20, y: 5), color: .green)
        let rendered = try XCTUnwrap(AnnotationRenderer.render(image: image, pointSize: CGSize(width: 40, height: 30),
                                                               annotations: [line]))
        XCTAssertEqual(rendered.width, 80)
        XCTAssertEqual(rendered.height, 60)
        XCTAssertEqual(pixel(rendered, x: 1, y: 1), [255, 0, 0, 255])
        XCTAssertEqual(pixel(rendered, x: 1, y: 58), [0, 0, 255, 255])
        XCTAssertEqual(pixel(rendered, x: 20, y: 10), [0, 255, 0, 255])
    }

    func testTextUsesTopLeftCoordinatesAndSupportsMultipleLines() throws {
        let image = try fixture(width: 160, height: 120)
        var text = Self.annotation(.text, start: CGPoint(x: 5, y: 3), end: .zero, color: .black)
        text.fontSize = 12
        text.text = "Hi\n你好"
        let rendered = try XCTUnwrap(AnnotationRenderer.render(image: image, pointSize: CGSize(width: 80, height: 60),
                                                               annotations: [text]))
        XCTAssertGreaterThan(text.bounds.height, 24)
        let darkRows = (0..<120).filter { y in (0..<160).contains { pixel(rendered, x: $0, y: y)[0] < 128 } }
        XCTAssertLessThan(try XCTUnwrap(darkRows.first), 20)
        XCTAssertGreaterThan(try XCTUnwrap(darkRows.last), 35)
        XCTAssertLessThan(try XCTUnwrap(darkRows.last), 75)
    }

    func testShapeHitTestingMovementAndTextResize() {
        let shape = Self.annotation(.rectangle, start: CGPoint(x: 70, y: 60), end: CGPoint(x: 10, y: 20))
        XCTAssertEqual(shape.bounds, CGRect(x: 10, y: 20, width: 60, height: 40))
        XCTAssertTrue(shape.contains(CGPoint(x: 30, y: 30), tolerance: 3))
        XCTAssertFalse(shape.contains(CGPoint(x: 85, y: 30), tolerance: 3))
        let moved = shape.moved(by: CGSize(width: 100, height: -100), within: CGSize(width: 100, height: 100))
        XCTAssertEqual(moved.bounds, CGRect(x: 40, y: 0, width: 60, height: 40))
        let resized = shape.resized(handle: 2, to: CGPoint(x: 90, y: 80))
        XCTAssertEqual(resized.bounds, CGRect(x: 10, y: 20, width: 80, height: 60))
        let line = Self.annotation(.line, start: .zero, end: CGPoint(x: 50, y: 50))
        XCTAssertTrue(line.contains(CGPoint(x: 25, y: 26), tolerance: 3))
        XCTAssertFalse(line.contains(CGPoint(x: 25, y: 40), tolerance: 3))
        var text = Self.annotation(.text, start: CGPoint(x: 10, y: 10), end: .zero)
        text.text = "Scale"
        let old = text.bounds
        let enlarged = text.resized(handle: 2, to: CGPoint(x: old.minX + old.width * 2, y: old.minY + old.height * 2))
        XCTAssertEqual(enlarged.fontSize, text.fontSize * 2, accuracy: 0.01)
        XCTAssertEqual(enlarged.start, text.start)
    }

    func testUndoGroupsGesturesAndStyleChangesAndTracksExport() async throws {
        let image = try fixture(width: 80, height: 60)
        await MainActor.run {
            let document = AnnotationDocument(image: image, pointSize: CGSize(width: 80, height: 60))
            var shape = Self.annotation(.rectangle, start: CGPoint(x: 5, y: 5), end: CGPoint(x: 30, y: 25))
            document.beginTransaction()
            document.update(shape)
            shape.end = CGPoint(x: 40, y: 30)
            document.update(shape)
            document.commitTransaction()
            document.select(shape.id)
            document.markExported()
            XCTAssertFalse(document.hasUnsavedChanges)
            document.beginStyleChange()
            document.setStrokeWidth(5)
            document.setStrokeWidth(9)
            document.finishStyleChange()
            XCTAssertTrue(document.hasUnsavedChanges)
            document.undo()
            XCTAssertEqual(document.annotations.first?.strokeWidth, 2)
            XCTAssertFalse(document.hasUnsavedChanges)
            document.undo()
            XCTAssertTrue(document.annotations.isEmpty)
            document.redo()
            XCTAssertEqual(document.annotations, [shape])
            document.beginTransaction()
            document.remove(shape.id)
            document.cancelTransaction()
            XCTAssertEqual(document.annotations, [shape])
            document.select(shape.id)
            document.deleteSelection()
            XCTAssertTrue(document.annotations.isEmpty)
            XCTAssertFalse(document.canRedo)
            document.undo()
            XCTAssertEqual(document.annotations, [shape])
        }
    }

    func testNativeTextEditingCommitsForExportAndEscapeRestoresOriginal() async throws {
        let image = try fixture(width: 160, height: 120)
        await MainActor.run {
            let document = AnnotationDocument(image: image, pointSize: CGSize(width: 160, height: 120))
            document.tool = .text
            let canvas = AnnotationCanvasView(document: document)
            canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
            let annotation = document.makeAnnotation(at: CGPoint(x: 10, y: 10))
            canvas.beginTextEditing(annotation, isNew: true)
            canvas.textView?.string = "你好\nHello"
            XCTAssertNotNil(document.renderedImage())
            XCTAssertNil(canvas.textView)
            XCTAssertEqual(document.annotations.first?.text, "你好\nHello")
            document.markExported()
            canvas.beginTextEditing(document.annotations[0], isNew: false)
            canvas.textView?.string = "Cancelled edit"
            canvas.textDidChange(Notification(name: NSText.didChangeNotification))
            XCTAssertTrue(document.hasUnsavedChanges)
            canvas.finishTextEditing(cancel: true)
            XCTAssertEqual(document.annotations.first?.text, "你好\nHello")
            XCTAssertFalse(document.hasUnsavedChanges)
            document.undo()
            XCTAssertTrue(document.annotations.isEmpty)
            canvas.beginTextEditing(document.makeAnnotation(at: .zero), isNew: true)
            canvas.finishTextEditing()
            XCTAssertTrue(document.annotations.isEmpty)
            XCTAssertFalse(document.canUndo)
        }
    }

    func testNativeCanvasGesturesDrawMoveCancelResizeAndUndo() async throws {
        let image = try fixture(width: 200, height: 150)
        await MainActor.run {
            let document = AnnotationDocument(image: image, pointSize: CGSize(width: 200, height: 150))
            let canvas = AnnotationCanvasView(document: document)
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = canvas
            defer { window.close() }
            @MainActor func mouse(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat) -> NSEvent {
                let point = CGPoint(x: canvas.imageOrigin.x + x * canvas.scale,
                                    y: canvas.imageOrigin.y + y * canvas.scale)
                return NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil),
                                          modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                          context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
            }
            document.setTool(.rectangle)
            canvas.mouseDown(with: mouse(.leftMouseDown, 20, 20))
            canvas.mouseDragged(with: mouse(.leftMouseDragged, 80, 60))
            canvas.mouseUp(with: mouse(.leftMouseUp, 80, 60))
            XCTAssertEqual(document.annotations.count, 1)
            let originalBounds = CGRect(x: 20, y: 20, width: 60, height: 40)
            XCTAssertEqual(document.annotations.first?.bounds, originalBounds)
            document.setTool(.select)
            canvas.mouseDown(with: mouse(.leftMouseDown, 50, 40))
            canvas.mouseDragged(with: mouse(.leftMouseDragged, 70, 60))
            canvas.mouseUp(with: mouse(.leftMouseUp, 70, 60))
            XCTAssertEqual(document.annotations.first?.bounds, CGRect(x: 40, y: 40, width: 60, height: 40))
            document.undo()
            XCTAssertEqual(document.annotations.first?.bounds, originalBounds)
            document.select(document.annotations.first?.id)
            canvas.mouseDown(with: mouse(.leftMouseDown, 80, 60))
            canvas.mouseDragged(with: mouse(.leftMouseDragged, 110, 90))
            XCTAssertEqual(document.annotations.first?.bounds, CGRect(x: 20, y: 20, width: 90, height: 70))
            canvas.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                 windowNumber: window.windowNumber, context: nil, characters: "\u{1B}",
                                                 charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53)!)
            XCTAssertEqual(document.annotations.first?.bounds, originalBounds)
            document.undo()
            XCTAssertTrue(document.annotations.isEmpty)
        }
    }

    private static func annotation(_ tool: AnnotationTool, start: CGPoint, end: CGPoint, color: NSColor = .red) -> Annotation {
        Annotation(tool: tool, start: start, end: end, color: color, strokeWidth: 2, fontSize: 24)
    }

    private func fixture(width: Int, height: Int, splitColors: Bool = false) throws -> CGImage {
        let bytes = (0..<height).flatMap { y -> [UInt8] in
            let color: [UInt8] = splitColors ? (y < height / 2 ? [255, 0, 0, 255] : [0, 0, 255, 255]) : [255, 255, 255, 255]
            return Array(repeating: color, count: width).flatMap { $0 }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        return try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let data = image.dataProvider!.data!
        let bytes = CFDataGetBytePtr(data)!
        let offset = y * image.bytesPerRow + x * 4
        return Array(UnsafeBufferPointer(start: bytes + offset, count: 4))
    }
}
