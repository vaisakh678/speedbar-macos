import AppKit
import SwiftUI

/// Preferences laid out like Hot's: a plain left-aligned column of checkboxes
/// and popup buttons, with the app mark sitting to the right — rather than
/// SwiftUI's boxed `.grouped` form style.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var monitor: SpeedMonitor

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            controls
            appMark
        }
        .padding(24)
        .frame(width: 620, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Show rates in bits (Mbps) instead of bytes (MB/s)", isOn: bitsBinding)

            Toggle("Show only the busier direction in the menu bar", isOn: dominantBinding)

            LabeledContent("Menu Bar Display:") {
                Picker("", selection: $settings.menuBarLayout) {
                    ForEach(AppSettings.MenuBarLayout.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            LabeledContent("Refresh Interval:") {
                Picker("", selection: $settings.refreshInterval) {
                    ForEach(AppSettings.refreshChoices, id: \.self) { value in
                        Text(AppSettings.refreshLabel(value)).tag(value)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Divider()
                .padding(.vertical, 4)

            Toggle("Start at login", isOn: $settings.launchAtLogin)
            Text("Requires a signed build — an ad-hoc development build cannot register a login item.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            sessionStats
        }
    }

    private var sessionStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Session download:", value: RateFormatter.totalString(bytes: monitor.sessionBytesIn))
            LabeledContent("Session upload:", value: RateFormatter.totalString(bytes: monitor.sessionBytesOut))
            LabeledContent("Peak download:", value: RateFormatter.string(bytesPerSecond: monitor.peakDownload, as: settings.rateUnit))
            Button("Reset Session Counters") { monitor.resetSession() }
                .padding(.top, 2)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The real app icon, which already carries its own squircle and the
    /// transparent margin Apple's grid reserves for a shadow — so it is drawn
    /// as-is, with only the shadow that margin exists for.
    private var appMark: some View {
        Group {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                // Only reachable if the asset catalog failed to build.
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(.quaternary)
                    .overlay(
                        Image(systemName: "speedometer")
                            .font(.system(size: 88, weight: .light))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 186, height: 186)
        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
    }

    private var bitsBinding: Binding<Bool> {
        Binding(
            get: { settings.rateUnit == .bits },
            set: { settings.rateUnit = $0 ? .bits : .bytes }
        )
    }

    /// The "busier direction" checkbox and the layout popup describe the same
    /// setting, so ticking the box selects that layout and unticking it falls
    /// back to the stacked view rather than leaving the popup stranded.
    private var dominantBinding: Binding<Bool> {
        Binding(
            get: { settings.menuBarLayout == .dominant },
            set: { settings.menuBarLayout = $0 ? .dominant : .stacked }
        )
    }
}
