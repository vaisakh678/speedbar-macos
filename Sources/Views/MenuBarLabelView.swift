import AppKit
import SwiftUI

/// The status-item content itself. The menu bar is contested space, so the
/// default shows one line: whichever direction is currently busier.
struct MenuBarLabelView: View {
    let download: Double
    let upload: Double
    let dominant: SpeedMonitor.Direction
    let unit: RateUnit
    let layout: AppSettings.MenuBarLayout
    /// Black is correct for the menu bar, where the render becomes a template
    /// image and only its alpha survives. The screenshot tool overrides it.
    var tint: Color = .black
    /// Drawn instead of a rate when there is no route to the internet — a
    /// reading of 0 B/s is indistinguishable from an idle connection.
    var isOffline: Bool = false

    /// A fixed width stops neighbouring menu bar items sliding sideways every
    /// time a digit is gained or lost.
    static let offlineWidth: CGFloat = 26

    static func width(for layout: AppSettings.MenuBarLayout) -> CGFloat {
        switch layout {
        case .dominant: 58
        case .stacked: 48
        case .downloadOnly: 58
        }
    }

    private static let barHeight: CGFloat = 22

    var body: some View {
        Group {
            if isOffline {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
            } else {
                content
            }
        }
        .frame(width: isOffline ? Self.offlineWidth : Self.width(for: layout),
               height: Self.barHeight)
        .foregroundStyle(tint)
        .help(isOffline ? "No internet connection" : "")
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch layout {
            case .dominant:
                let isUpload = dominant == .upload
                singleRow(
                    symbol: isUpload ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill",
                    value: isUpload ? upload : download
                )

            case .downloadOnly:
                singleRow(symbol: "arrowtriangle.down.fill", value: download)

            case .stacked:
                VStack(alignment: .trailing, spacing: 0) {
                    compactRow(symbol: "arrowtriangle.up.fill", value: upload)
                    compactRow(symbol: "arrowtriangle.down.fill", value: download)
                }
            }
        }
    }

    private func singleRow(symbol: String, value: Double) -> some View {
        let parts = RateFormatter.compactComponents(bytesPerSecond: value, as: unit)
        return HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(parts.value + parts.unit)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
        }
    }

    /// Two rows have to share 22pt, so each gets an explicit height — left to
    /// its own devices the text overflows the frame and the lower row clips.
    private func compactRow(symbol: String, value: Double) -> some View {
        let parts = RateFormatter.compactComponents(bytesPerSecond: value, as: unit)
        return HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .bold))
            Text(parts.value + parts.unit)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
        }
        .frame(height: 10)
    }
}

/// Rasterises `MenuBarLabelView` into a template `NSImage`.
///
/// `MenuBarExtra` does not render a composed SwiftUI label faithfully — a
/// multi-row `VStack` comes out with rows and text silently dropped. Rendering
/// the view ourselves and handing `MenuBarExtra` a single `Image` sidesteps
/// that, and as a template image it tracks light/dark automatically.
@MainActor
enum MenuBarLabelRenderer {

    static func image(
        download: Double,
        upload: Double,
        dominant: SpeedMonitor.Direction,
        unit: RateUnit,
        layout: AppSettings.MenuBarLayout,
        isOffline: Bool
    ) -> NSImage? {
        let renderer = ImageRenderer(
            content: MenuBarLabelView(
                download: download,
                upload: upload,
                dominant: dominant,
                unit: unit,
                layout: layout,
                isOffline: isOffline
            )
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}
