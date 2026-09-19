import SwiftUI

@main
struct WirespeedApp: App {

    @State private var settings: AppSettings
    @State private var monitor: SpeedMonitor
    @State private var tester = SpeedTester()
    @State private var publicAddress = PublicAddressLookup()

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        let monitor = SpeedMonitor(settings: settings, path: NetworkPathObserver())
        _monitor = State(initialValue: monitor)

        // Sampling has to begin at launch, not when the panel is first opened —
        // the menu bar label is live from the moment the app appears.
        monitor.start()
    }

    var body: some Scene {
        MenuBarExtra {
            SpeedPanelView(
                monitor: monitor,
                settings: settings,
                tester: tester,
                publicAddress: publicAddress
            )
            // A cached public IP is wrong the moment the route changes.
            .onChange(of: monitor.pathObserver.activeLink) { publicAddress.invalidate() }
        } label: {
            // Handed a pre-rendered image rather than the view itself; see
            // MenuBarLabelRenderer for why.
            if let image = MenuBarLabelRenderer.image(
                download: monitor.download,
                upload: monitor.upload,
                dominant: monitor.dominantDirection,
                unit: settings.rateUnit,
                layout: settings.menuBarLayout,
                isOffline: monitor.pathObserver.hasEvaluatedPath && !monitor.pathObserver.isOnline
            ) {
                Image(nsImage: image)
            } else {
                Image(systemName: "speedometer")
            }
        }
        // `.window` gives us a real SwiftUI panel instead of an NSMenu, which an
        // NSMenu cannot host (no live chart, no buttons with state).
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, monitor: monitor)
        }
    }
}
