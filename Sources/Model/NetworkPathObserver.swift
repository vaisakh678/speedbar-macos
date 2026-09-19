import Foundation
import Network
import Observation

/// Describes which interface the system is currently routing internet traffic
/// over, so the meter can measure that one rather than summing every adapter
/// (which would double-count when a VPN is up).
@MainActor
@Observable
final class NetworkPathObserver {

    struct Link: Equatable {
        var name: String
        var kind: NWInterface.InterfaceType

        var displayName: String {
            switch kind {
            case .wifi: "Wi-Fi"
            case .wiredEthernet: "Ethernet"
            case .cellular: "Cellular"
            case .loopback: "Loopback"
            case .other: "Other"
            @unknown default: "Unknown"
            }
        }

        var symbolName: String {
            switch kind {
            case .wifi: "wifi"
            case .wiredEthernet: "cable.connector"
            case .cellular: "antenna.radiowaves.left.and.right"
            case .loopback: "arrow.triangle.2.circlepath"
            case .other: "network"
            @unknown default: "network"
            }
        }
    }

    /// The interface carrying traffic right now, or `nil` when offline.
    private(set) var activeLink: Link?
    private(set) var isOnline = false
    /// False until NWPathMonitor's first callback. Without this the menu bar
    /// would flash "offline" for a moment at every launch.
    private(set) var hasEvaluatedPath = false
    /// True when the route runs through a VPN or similar tunnel, in which case
    /// the byte counts include tunnel overhead.
    private(set) var isTunneled = false
    /// LAN address of `activeLink`, e.g. "192.168.1.42".
    private(set) var localAddress: String?

    /// A preview observer holds fixed values; refreshing would overwrite them
    /// with the host machine's real address.
    private var isPreview = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.cortexlumora.Wirespeed.path")

    init(startMonitoring: Bool = true) {
        guard startMonitoring else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            // NWPathMonitor calls back on its own queue; hop to the main actor
            // before touching observable state.
            Task { @MainActor [weak self] in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// A fixed observer with no live monitoring, for SwiftUI previews and the
    /// generated App Store screenshots.
    static func preview(link: Link?, localAddress: String?, tunneled: Bool = false) -> NetworkPathObserver {
        let observer = NetworkPathObserver(startMonitoring: false)
        observer.isPreview = true
        observer.activeLink = link
        observer.localAddress = localAddress
        observer.isOnline = link != nil
        observer.hasEvaluatedPath = true
        observer.isTunneled = tunneled
        return observer
    }

    private func apply(_ path: NWPath) {
        hasEvaluatedPath = true
        isOnline = path.status == .satisfied

        // `availableInterfaces` is ordered by the system's own preference, so
        // the first non-loopback entry is the one actually carrying traffic.
        let primary = path.availableInterfaces.first { $0.type != .loopback }
        activeLink = primary.map { Link(name: $0.name, kind: $0.type) }

        isTunneled = path.availableInterfaces.contains { $0.name.hasPrefix("utun") || $0.name.hasPrefix("ipsec") }
        refreshLocalAddress()
    }

    /// DHCP can hand out a new address without the path itself changing, so
    /// the panel re-reads this each time it opens.
    func refreshLocalAddress() {
        guard !isPreview else { return }
        localAddress = activeLink.flatMap { LocalAddressReader.address(for: $0.name) }
    }
}
