// Builds the macOS AppIcon asset from a single square source image.
//
//   swift Tools/make-appicon.swift Design/icon-source.png Resources/Assets.xcassets
//
// Apple's icon grid places the artwork in an 824x824 rounded square centred on
// a 1024x1024 canvas, leaving the surrounding margin transparent — the system
// draws its own shadow there. The corner is a *continuous* curve, not a
// circular arc, which is why this renders through SwiftUI's
// RoundedRectangle(style: .continuous) rather than compositing with sips.

import AppKit
import SwiftUI

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: make-appicon <source.png> <Assets.xcassets>\n".utf8))
    exit(2)
}

let sourcePath = arguments[1]
let catalogURL = URL(fileURLWithPath: arguments[2])
let iconSetURL = catalogURL.appendingPathComponent("AppIcon.appiconset")

guard let source = NSImage(contentsOfFile: sourcePath) else {
    FileHandle.standardError.write(Data("cannot read \(sourcePath)\n".utf8))
    exit(1)
}

let canvas: CGFloat = 1024
let body: CGFloat = 824
let cornerRadius: CGFloat = 185.4

let master: NSImage = MainActor.assumeIsolated {
    let content = Image(nsImage: source)
        .resizable()
        .interpolation(.high)
        .aspectRatio(contentMode: .fill)
        .frame(width: body, height: body)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: canvas, height: canvas)

    let renderer = ImageRenderer(content: content)
    renderer.scale = 1
    guard let image = renderer.nsImage else {
        FileHandle.standardError.write(Data("render failed\n".utf8))
        exit(1)
    }
    return image
}

func writePNG(_ image: NSImage, side: Int, to url: URL) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    rep.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
               from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: url)
    }
}

try? FileManager.default.createDirectory(at: iconSetURL, withIntermediateDirectories: true)

// macOS wants each logical size at both 1x and 2x.
let entries: [(size: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2),
    (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

var images: [[String: String]] = []
var written = Set<Int>()

for entry in entries {
    let pixels = entry.size * entry.scale
    let filename = "icon_\(pixels).png"
    if !written.contains(pixels) {
        writePNG(master, side: pixels, to: iconSetURL.appendingPathComponent(filename))
        written.insert(pixels)
    }
    images.append([
        "idiom": "mac",
        "size": "\(entry.size)x\(entry.size)",
        "scale": "\(entry.scale)x",
        "filename": filename,
    ])
}

let contents: [String: Any] = [
    "images": images,
    "info": ["version": 1, "author": "xcode"],
]
let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: iconSetURL.appendingPathComponent("Contents.json"))

// The catalog itself needs a Contents.json too.
let catalogInfo = try JSONSerialization.data(
    withJSONObject: ["info": ["version": 1, "author": "xcode"]],
    options: [.prettyPrinted]
)
try catalogInfo.write(to: catalogURL.appendingPathComponent("Contents.json"))

print("wrote \(written.count) sizes to \(iconSetURL.path)")
