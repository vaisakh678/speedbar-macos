import Foundation
import Observation
import ServiceManagement

/// User preferences, persisted in `UserDefaults` and observed by the views.
@MainActor
@Observable
final class AppSettings {

    /// How the two rates are laid out in the menu bar itself.
    enum MenuBarLayout: String, CaseIterable, Identifiable, Sendable {
        case dominant       // one line, whichever direction is busier
        case stacked        // upload over download, two small lines
        case downloadOnly   // one line, always the download rate

        var id: String { rawValue }

        var label: String {
            switch self {
            case .dominant: "Busier direction"
            case .stacked: "Both, stacked"
            case .downloadOnly: "Download only"
            }
        }
    }

    var rateUnit: RateUnit {
        didSet { defaults.set(rateUnit.rawValue, forKey: Key.rateUnit) }
    }

    var menuBarLayout: MenuBarLayout {
        didSet { defaults.set(menuBarLayout.rawValue, forKey: Key.menuBarLayout) }
    }

    /// Sampling period in seconds. Shorter is more responsive but noisier.
    var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval) }
    }

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin()
        }
    }

    /// Discrete choices for the popup, in place of a free-running slider.
    static let refreshChoices: [Double] = [0.5, 1, 2, 5]

    static func refreshLabel(_ value: Double) -> String {
        if value < 1 { return "\(Int(value * 1000)) ms" }
        return value == 1 ? "1 second" : "\(Int(value)) seconds"
    }

    private let defaults: UserDefaults

    private enum Key {
        static let rateUnit = "rateUnit"
        static let menuBarLayout = "menuBarLayout"
        static let refreshInterval = "refreshInterval"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.rateUnit = defaults.string(forKey: Key.rateUnit)
            .flatMap(RateUnit.init(rawValue:)) ?? .bytes
        self.menuBarLayout = defaults.string(forKey: Key.menuBarLayout)
            .flatMap(MenuBarLayout.init(rawValue:)) ?? .dominant
        // `double(forKey:)` returns 0 for a missing key, which would be an
        // infinitely tight timer loop — fall back to 1s in that case.
        let storedInterval = defaults.double(forKey: Key.refreshInterval)
        self.refreshInterval = storedInterval > 0 ? storedInterval : 1.0

        // The login-item state lives in the system, not in our defaults, so
        // read it back from SMAppService rather than trusting a cached copy.
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration fails for unsigned/ad-hoc builds. Roll the toggle
            // back so the UI keeps reflecting reality.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
