import CoreGraphics

enum CaptureGeometry {
    /// AppKit desktop coordinates are bottom-left; CGImage crop coordinates are top-left.
    static func pixelRect(for selection: CGRect, screenFrame: CGRect, pixelSize: CGSize) -> CGRect? {
        let values = [selection.minX, selection.minY, selection.width, selection.height,
                      screenFrame.minX, screenFrame.minY, screenFrame.width, screenFrame.height,
                      pixelSize.width, pixelSize.height]
        guard values.allSatisfy(\.isFinite), screenFrame.width > 0, screenFrame.height > 0,
              pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        let clipped = selection.standardized.intersection(screenFrame)
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        let scaleX = pixelSize.width / screenFrame.width
        let scaleY = pixelSize.height / screenFrame.height
        let left = floor((clipped.minX - screenFrame.minX) * scaleX)
        let top = floor((screenFrame.maxY - clipped.maxY) * scaleY)
        let right = ceil((clipped.maxX - screenFrame.minX) * scaleX)
        let bottom = ceil((screenFrame.maxY - clipped.minY) * scaleY)
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
            .intersection(CGRect(origin: .zero, size: pixelSize))
    }
}
