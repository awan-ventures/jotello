#!/usr/bin/env swift
import AppKit

// Renders Resources/Icon.svg into the macOS app icon set, inset to the standard 824/1024 grid,
// and Resources/MenuBarIcon.svg (the same viewfinder and J) into an 18 pt template image.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Resources/Icon.svg")
let destination = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
guard let svg = NSImage(contentsOf: source) else { fatalError("Couldn't read \(source.path)") }

func render(_ svg: NSImage, pixels: Int, inset: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    svg.draw(in: NSRect(x: inset, y: inset, width: CGFloat(pixels) - inset * 2,
                        height: CGFloat(pixels) - inset * 2))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try render(svg, pixels: size * scale, inset: CGFloat(size * scale) * 100 / 1024).write(to: destination.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let catalog: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
try json.write(to: destination.appendingPathComponent("Contents.json"))
print("Generated 10 macOS app icons in \(destination.path)")

let menuSource = root.appendingPathComponent("Resources/MenuBarIcon.svg")
let menuDestination = root.appendingPathComponent("Resources/Assets.xcassets/MenuBarIcon.imageset")
try FileManager.default.createDirectory(at: menuDestination, withIntermediateDirectories: true)
guard let menuSVG = NSImage(contentsOf: menuSource) else { fatalError("Couldn't read \(menuSource.path)") }
var menuImages: [[String: String]] = []
for scale in [1, 2] {
    let name = "menubar@\(scale)x.png"
    try render(menuSVG, pixels: 18 * scale, inset: 0).write(to: menuDestination.appendingPathComponent(name))
    menuImages.append(["idiom": "mac", "scale": "\(scale)x", "filename": name])
}
let menuCatalog: [String: Any] = ["images": menuImages, "info": ["author": "xcode", "version": 1],
                                  "properties": ["template-rendering-intent": "template"]]
try JSONSerialization.data(withJSONObject: menuCatalog, options: [.prettyPrinted, .sortedKeys])
    .write(to: menuDestination.appendingPathComponent("Contents.json"))
print("Generated the menu bar icon in \(menuDestination.path)")
