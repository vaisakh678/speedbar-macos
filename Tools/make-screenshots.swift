// Renders the App Store screenshots from the app's own SwiftUI views.
//
//   swift Tools/make-screenshots.swift Design/screenshots
//
// The views are rendered offscreen with ImageRenderer rather than captured
// from a running app: a menu bar panel cannot be screenshotted without also
// capturing whatever is on the desktop behind it, and driving the status item
// through the Accessibility API is unreliable. Rendering the real views keeps
// the shots honest while making them deterministic and clean.

import AppKit
import ImageIO
import SwiftUI

// Unbuffered, so progress survives if a draw call traps.
setvbuf(stdout, nil, _IONBF, 0)

// AppKit drawing and ImageRenderer need a live NSApplication, even headless.
private let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Design/screenshots")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// 2880x1800 is one of the four sizes the Mac App Store accepts.
let canvasSize = CGSize(width: 2880, height: 1800)

// MARK: - Sample data

@MainActor
func sampleHistory() -> [SpeedSample] {
    // A plausible minute: idle, a burst, a tail off, a smaller second burst.
    let shape: [Double] = [
        0.02, 0.03, 0.02, 0.05, 0.30, 0.72, 0.95, 0.88, 0.91, 0.80,
        0.74, 0.83, 0.90, 0.76, 0.55, 0.32, 0.18, 0.09, 0.05, 0.04,
        0.03, 0.02, 0.02, 0.06, 0.22, 0.48, 0.62, 0.58, 0.44, 0.30,
        0.19, 0.12, 0.08, 0.05, 0.04, 0.03, 0.03, 0.02, 0.02, 0.03,
        0.10, 0.28, 0.51, 0.69, 0.77, 0.71, 0.60, 0.46, 0.33, 0.24,
        0.16, 0.11, 0.07, 0.09, 0.24, 0.52, 0.78, 0.89, 0.94, 0.96,
    ]
    let peak = 11_800_000.0     // ~11.8 MB/s down
    let now = Date()
    return shape.enumerated().map { index, value in
        SpeedSample(
            timestamp: now.addingTimeInterval(Double(index - shape.count)),
            download: value * peak,
            upload: value * peak * 0.11 + 22_000
        )
    }
}

@MainActor
func makePanel(dominant: SpeedMonitor.Direction, publicIP: PublicAddressLookup.State) -> some View {
    let settings = AppSettings(
        defaults: UserDefaults(suiteName: "screenshots") ?? .standard,
        readsLoginItem: false
    )
    settings.rateUnit = .bytes
    let history = sampleHistory()
    let path = NetworkPathObserver.preview(
        link: .init(name: "en0", kind: .wifi),
        localAddress: "192.168.1.24"
    )
    let monitor = SpeedMonitor.preview(
        settings: settings,
        path: path,
        download: history.last!.download,
        upload: history.last!.upload,
        history: history,
        sessionIn: 2_411_724_390,
        sessionOut: 184_905_216,
        dominant: dominant
    )
    // The panel normally sits inside a system-drawn menu bar window; rendered
    // on its own it has no background, so give it the same chrome.
    return SpeedPanelView(
        monitor: monitor,
        settings: settings,
        tester: SpeedTester.preview(phase: .idle),
        publicAddress: PublicAddressLookup.preview(state: publicIP)
    )
    .background(Color(red: 0.13, green: 0.13, blue: 0.145))
    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
    )
    .environment(\.colorScheme, .dark)
}

// MARK: - Rendering helpers

@MainActor
func render<V: View>(_ view: V, scale: CGFloat, label: String) -> NSImage {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.nsImage, image.size.width > 1 else {
        FileHandle.standardError.write(Data("render failed: \(label)\n".utf8))
        exit(1)
    }
    return image
}

func canvas(_ draw: (CGContext, CGSize) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width), pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        FileHandle.standardError.write(Data("canvas: no graphics context\n".utf8)); exit(1)
    }
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext, canvasSize)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func fillBackground(_ ctx: CGContext, _ size: CGSize) {
    // Same palette as the app icon, so the listing reads as one thing.
    let colors = [
        NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.11, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.02, green: 0.025, blue: 0.04, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: 0), options: [])

    // A soft blue bloom behind the artwork, echoing the icon's glow.
    let bloom = [
        NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 0.30).cgColor,
        NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 0.0).cgColor,
    ] as CFArray
    let radial = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bloom, locations: [0, 1])!
    ctx.drawRadialGradient(
        radial,
        startCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.42), startRadius: 0,
        endCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.42), endRadius: size.width * 0.5,
        options: []
    )
}

func drawText(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerX: CGFloat, y: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let bounds = attributed.size()
    attributed.draw(at: CGPoint(x: centerX - bounds.width / 2, y: y))
}

func drawImage(_ image: NSImage, centerX: CGFloat, bottomY: CGFloat, width: CGFloat, shadow: Bool = true) {
    let aspect = image.size.height / image.size.width
    let rect = NSRect(x: centerX - width / 2, y: bottomY, width: width, height: width * aspect)
    if shadow {
        NSGraphicsContext.current?.saveGraphicsState()
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.55)
        s.shadowBlurRadius = 60
        s.shadowOffset = NSSize(width: 0, height: -18)
        s.set()
    }
    image.draw(in: rect)
    if shadow { NSGraphicsContext.current?.restoreGraphicsState() }
}

func write(_ rep: NSBitmapImageRep, _ name: String) {
    let url = outDir.appendingPathComponent(name)
    let width = rep.pixelsWide, height = rep.pixelsHigh

    // App Store screenshots must be RGB with no alpha channel. Compositing
    // onto an opaque CGContext with .noneSkipLast drops the alpha at encode
    // time; NSBitmapImageRep with samplesPerPixel 3 refuses to allocate here.
    guard let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("write: no CGContext for \(name)\n".utf8)); exit(1)
    }

    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if let source = rep.cgImage {
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        FileHandle.standardError.write(Data("write: encode failed for \(name)\n".utf8)); exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write(Data("write: finalize failed for \(name)\n".utf8)); exit(1)
    }
    print("wrote \(name)  \(width)x\(height)  alpha=\(image.alphaInfo != .none)")
}

// MARK: - Shots

MainActor.assumeIsolated {
    let panelDown = render(makePanel(dominant: .download, publicIP: .idle), scale: 6, label: "panel")
    let panelIP = render(makePanel(dominant: .download, publicIP: .found("103.183.83.111")), scale: 6, label: "panel-ip")
    let labelDown = render(MenuBarLabelView(download: 11_800_000, upload: 1_290_000,
                                            dominant: .download, unit: .bytes,
                                            layout: .dominant, tint: .white),
                           scale: 14, label: "label-down")
    let labelUp = render(MenuBarLabelView(download: 240_000, upload: 6_400_000,
                                          dominant: .upload, unit: .bytes,
                                          layout: .dominant, tint: .white),
                         scale: 14, label: "label-up")
    print("rendered: panel \(panelDown.size), label \(labelDown.size)")

    print("composing 1...")
    // 1 — the panel
    write(canvas { ctx, size in
        fillBackground(ctx, size)
        drawText("Your real speed, in the menu bar", size: 108, weight: .semibold, color: .white,
                 centerX: size.width / 2, y: size.height - 230)
        drawText("Live throughput read straight from macOS. No background traffic.",
                 size: 50, weight: .regular, color: NSColor.white.withAlphaComponent(0.55),
                 centerX: size.width / 2, y: size.height - 320)
        drawImage(panelDown, centerX: size.width / 2, bottomY: 180, width: 820)
    }, "01-panel.png")

    print("composing 2...")
    // 2 — the menu bar glyph, both directions
    write(canvas { ctx, size in
        fillBackground(ctx, size)
        drawText("One glyph. Whichever way traffic is flowing.", size: 104, weight: .semibold, color: .white,
                 centerX: size.width / 2, y: size.height - 280)
        drawText("The arrow follows the busier direction, so the meter stays narrow.",
                 size: 52, weight: .regular, color: NSColor.white.withAlphaComponent(0.55),
                 centerX: size.width / 2, y: size.height - 378)
        drawImage(labelDown, centerX: size.width / 2 - 460, bottomY: 720, width: 620, shadow: false)
        drawImage(labelUp, centerX: size.width / 2 + 460, bottomY: 720, width: 620, shadow: false)
        drawText("downloading", size: 46, weight: .medium, color: NSColor(calibratedRed: 0.36, green: 0.66, blue: 1, alpha: 0.9),
                 centerX: size.width / 2 - 460, y: 600)
        drawText("uploading", size: 46, weight: .medium, color: NSColor(calibratedRed: 1, green: 0.62, blue: 0.24, alpha: 0.9),
                 centerX: size.width / 2 + 460, y: 600)
    }, "02-menubar.png")

    print("composing 3...")
    // 3 — IP addresses
    write(canvas { ctx, size in
        fillBackground(ctx, size)
        drawText("Copy your IP without leaving the menu bar", size: 98, weight: .semibold, color: .white,
                 centerX: size.width / 2, y: size.height - 230)
        drawText("Local address always shown. Public address only when you ask for it.",
                 size: 50, weight: .regular, color: NSColor.white.withAlphaComponent(0.55),
                 centerX: size.width / 2, y: size.height - 320)
        drawImage(panelIP, centerX: size.width / 2, bottomY: 180, width: 820)
    }, "03-ip.png")
}
