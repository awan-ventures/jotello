import AppKit

enum AnnotationRenderer {
    /// The caller supplies a context with its origin at the top left, measured in image points.
    static func draw(image: CGImage, pointSize: CGSize, annotations: [Annotation],
                     in context: CGContext, excluding excludedID: UUID? = nil) {
        context.saveGState()
        context.clip(to: CGRect(origin: .zero, size: pointSize))
        context.saveGState()
        context.translateBy(x: 0, y: pointSize.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: pointSize))
        context.restoreGState()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        for annotation in annotations where annotation.id != excludedID {
            if annotation.tool == .text {
                (annotation.text as NSString).draw(at: annotation.start, withAttributes: annotation.attributes)
            } else {
                context.setStrokeColor(annotation.color.cgColor)
                context.setLineWidth(annotation.strokeWidth)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.addPath(annotation.shapePath())
                context.strokePath()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    static func render(image: CGImage, pointSize: CGSize, annotations: [Annotation]) -> CGImage? {
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: CGFloat(image.width) / pointSize.width,
                        y: -CGFloat(image.height) / pointSize.height)
        draw(image: image, pointSize: pointSize, annotations: annotations, in: context)
        return context.makeImage()
    }
}
