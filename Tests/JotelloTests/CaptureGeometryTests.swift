import XCTest
@testable import Jotello

final class CaptureGeometryTests: XCTestCase {
    func testRetinaCropConvertsBottomLeftToTopLeftPixels() {
        XCTAssertEqual(CaptureGeometry.pixelRect(
            for: CGRect(x: 20, y: 60, width: 30, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            pixelSize: CGSize(width: 200, height: 200)
        ), CGRect(x: 40, y: 40, width: 60, height: 40))
    }

    func testMonitorWithNegativeOriginAndClippedSelection() {
        XCTAssertEqual(CaptureGeometry.pixelRect(
            for: CGRect(x: -210, y: -75, width: 50, height: 50),
            screenFrame: CGRect(x: -200, y: -100, width: 100, height: 100),
            pixelSize: CGSize(width: 100, height: 100)
        ), CGRect(x: 0, y: 25, width: 40, height: 50))
    }

    func testFractionalRegionIncludesAllSelectedPixels() {
        XCTAssertEqual(CaptureGeometry.pixelRect(
            for: CGRect(x: 1.2, y: 3.2, width: 2.1, height: 1.1),
            screenFrame: CGRect(x: 0, y: 0, width: 10, height: 10),
            pixelSize: CGSize(width: 20, height: 20)
        ), CGRect(x: 2, y: 11, width: 5, height: 3))
    }

    func testEmptyAndOutsideRegionsAreRejected() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        for selection in [CGRect.zero, CGRect(x: 200, y: 200, width: 10, height: 10)] {
            XCTAssertNil(CaptureGeometry.pixelRect(for: selection, screenFrame: frame,
                                                   pixelSize: CGSize(width: 200, height: 200)))
        }
        XCTAssertNil(CaptureGeometry.pixelRect(for: frame, screenFrame: .zero,
                                               pixelSize: CGSize(width: 200, height: 200)))
    }
}
