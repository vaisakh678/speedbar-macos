import AppKit
import SwiftUI

/// The dropdown shown when the status item is clicked, laid out like a
/// standard `NSMenu`: readout rows, a graph card, then the action items.
struct SpeedPanelView: View {
    @Bindable var monitor: SpeedMonitor
    @Bindable var settings: AppSettings
    @Bindable var tester: SpeedTester
    @Bindable var publicAddress: PublicAddressLookup

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuActionRow(title: "About Wirespeed") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }

            MenuSeparator()

            MenuReadoutRow(
                systemImage: "arrowtriangle.down.fill",
                title: "Download:",
                value: RateFormatter.string(bytesPerSecond: monitor.download, as: settings.rateUnit),
                tint: TrafficGraphCard.downloadColor
            )
            MenuReadoutRow(
                systemImage: "arrowtriangle.up.fill",
                title: "Upload:",
                value: RateFormatter.string(bytesPerSecond: monitor.upload, as: settings.rateUnit),
                tint: TrafficGraphCard.uploadColor
            )

            TrafficGraphCard(samples: monitor.history, unit: settings.rateUnit)
                .padding(.vertical, 6)

            MenuReadoutRow(
                systemImage: link?.symbolName ?? "wifi.slash",
                title: "Connection:",
                value: connectionValue
            )
            if let localAddress = monitor.pathObserver.localAddress {
                MenuCopyRow(
                    systemImage: "house.fill",
                    title: "Local IP:",
                    value: localAddress
                )
            }

            publicAddressSection

            MenuReadoutRow(
                systemImage: "chart.bar.fill",
                title: "Session:",
                value: "↓\(RateFormatter.totalString(bytes: monitor.sessionBytesIn))  ↑\(RateFormatter.totalString(bytes: monitor.sessionBytesOut))"
            )

            MenuSeparator()

            speedTestSection

            MenuSeparator()

            MenuActionRow(title: "Preferences…", shortcut: "⌘,") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            MenuActionRow(title: "Reset Session Counters") {
                monitor.resetSession()
            }

            MenuSeparator()

            MenuActionRow(title: "Quit", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 6)
        .frame(width: MenuMetrics.width)
        .onAppear { monitor.pathObserver.refreshLocalAddress() }
    }

    @ViewBuilder
    private var publicAddressSection: some View {
        switch publicAddress.state {
        case .idle:
            MenuActionRow(title: "Look Up Public IP", systemImage: "globe") { publicAddress.lookUp() }

        case .looking:
            MenuReadoutRow(systemImage: "globe", title: "Public IP:", value: "Looking up…")

        case .found(let address):
            MenuCopyRow(systemImage: "globe", title: "Public IP:", value: address)

        case .failed:
            MenuActionRow(title: "Public IP unavailable — Retry", systemImage: "globe") { publicAddress.lookUp() }
        }
    }

    private var link: NetworkPathObserver.Link? {
        monitor.pathObserver.activeLink
    }

    private var connectionValue: String {
        guard let link else { return "Offline" }
        let tunnel = monitor.pathObserver.isTunneled ? " · VPN" : ""
        return "\(link.displayName) (\(link.name))\(tunnel)"
    }

    @ViewBuilder
    private var speedTestSection: some View {
        switch tester.phase {
        case .idle:
            MenuActionRow(title: "Run Speed Test") { tester.run() }

        case .latency, .download, .upload:
            MenuReadoutRow(
                systemImage: "gauge.with.dots.needle.33percent",
                title: testPhaseLabel,
                value: tester.liveRate > 0
                    ? RateFormatter.string(bytesPerSecond: tester.liveRate, as: settings.rateUnit)
                    : "…"
            )
            MenuActionRow(title: "Cancel Test") { tester.cancel() }

        case .finished:
            if let result = tester.result {
                MenuReadoutRow(
                    systemImage: "arrowtriangle.down.fill",
                    title: "Test download:",
                    value: RateFormatter.string(bytesPerSecond: result.downloadBytesPerSecond, as: settings.rateUnit),
                    tint: TrafficGraphCard.downloadColor
                )
                MenuReadoutRow(
                    systemImage: "arrowtriangle.up.fill",
                    title: "Test upload:",
                    value: RateFormatter.string(bytesPerSecond: result.uploadBytesPerSecond, as: settings.rateUnit),
                    tint: TrafficGraphCard.uploadColor
                )
                MenuReadoutRow(
                    systemImage: "bolt.fill",
                    title: "Latency:",
                    value: "\(result.latency.milliseconds) ms"
                )
            }
            MenuActionRow(title: "Run Speed Test Again") { tester.run() }

        case .failed(let message):
            MenuReadoutRow(
                systemImage: "exclamationmark.triangle.fill",
                title: "Test failed:",
                value: message
            )
            MenuActionRow(title: "Retry Speed Test") { tester.run() }
        }
    }

    private var testPhaseLabel: String {
        switch tester.phase {
        case .latency: "Measuring latency…"
        case .download: "Testing download…"
        case .upload: "Testing upload…"
        default: ""
        }
    }
}

extension Duration {
    var milliseconds: Int {
        Int(Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15)
    }
}
