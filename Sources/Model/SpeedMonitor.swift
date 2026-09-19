import Foundation
import Observation

/// Samples the active interface's byte counters on a timer and turns the
/// deltas into a live throughput reading plus a short rolling history.
@MainActor
@Observable
final class SpeedMonitor {

    /// How many samples the sparkline keeps. At the default 1s interval this is
    /// a 60-second window.
    static let historyLength = 60

    /// Which way traffic is mostly flowing, for the single-line menu bar label.
    enum Direction: Sendable { case download, upload }

    private(set) var dominantDirection: Direction = .download

    private(set) var download: Double = 0
    private(set) var upload: Double = 0
    private(set) var history: [SpeedSample] = []

    /// Traffic observed since the app launched, on the interfaces we watched.
    private(set) var sessionBytesIn: UInt64 = 0
    private(set) var sessionBytesOut: UInt64 = 0

    /// Peak download rate seen this session, for scaling context.
    private(set) var peakDownload: Double = 0

    var pathObserver: NetworkPathObserver { path }

    private let path: NetworkPathObserver
    private let settings: AppSettings

    private var lastCounters: InterfaceCounters?
    private var lastInterfaceName: String?
    private var lastSampledAt: Date?
    private var task: Task<Void, Never>?

    init(settings: AppSettings, path: NetworkPathObserver = NetworkPathObserver()) {
        self.settings = settings
        self.path = path
    }

    func start() {
        guard task == nil else { return }
        // Held weakly: if the monitor is deallocated the loop exits on its next
        // pass, so there is no deinit to cancel it from (a deinit is
        // nonisolated and could not touch this main-actor state anyway).
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                // Read the interval each pass so a settings change takes effect
                // without restarting the loop.
                let interval = self.settings.refreshInterval
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func resetSession() {
        sessionBytesIn = 0
        sessionBytesOut = 0
        peakDownload = 0
        history.removeAll()
    }

    private func tick() {
        let now = Date()
        let counters = InterfaceCountersReader.readAll()

        // Prefer the interface the system says is carrying traffic. When that is
        // unknown (offline, or a path update has not landed yet), fall back to
        // summing the physical adapters so the meter still shows something.
        let interfaceName = path.activeLink?.name
        let current: InterfaceCounters? = if let interfaceName {
            counters[interfaceName]
        } else {
            counters.isEmpty ? nil : Self.sumPhysical(counters)
        }

        guard let current else {
            record(download: 0, upload: 0, at: now)
            return
        }

        // Switching interfaces (Wi-Fi to Ethernet, VPN up) hands us a counter
        // from a different origin, so rebaseline instead of reporting the
        // meaningless difference between the two.
        guard let previous = lastCounters,
              let previousAt = lastSampledAt,
              lastInterfaceName == interfaceName else {
            lastCounters = current
            lastInterfaceName = interfaceName
            lastSampledAt = now
            record(download: 0, upload: 0, at: now)
            return
        }

        let elapsed = now.timeIntervalSince(previousAt)
        guard elapsed > 0.01 else { return }

        let deltaIn = Self.delta(from: previous.bytesIn, to: current.bytesIn, over: elapsed)
        let deltaOut = Self.delta(from: previous.bytesOut, to: current.bytesOut, over: elapsed)

        sessionBytesIn += deltaIn
        sessionBytesOut += deltaOut

        lastCounters = current
        lastInterfaceName = interfaceName
        lastSampledAt = now

        record(download: Double(deltaIn) / elapsed, upload: Double(deltaOut) / elapsed, at: now)
    }

    private func record(download: Double, upload: Double, at timestamp: Date) {
        self.download = download
        self.upload = upload
        peakDownload = max(peakDownload, download)
        updateDominantDirection()

        history.append(SpeedSample(timestamp: timestamp, download: download, upload: upload))
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
    }

    /// The counters wrap at 2^32 (see `InterfaceCountersReader`), so a value
    /// going backwards usually means a wrap, not an interface reset. Unfold it
    /// rather than dropping the interval's traffic on the floor.
    private static func delta(from previous: UInt64, to current: UInt64, over elapsed: TimeInterval) -> UInt64 {
        if current >= previous { return current - previous }

        // Only plausible as a wrap if the old reading was inside 32-bit range.
        guard previous <= UInt64(UInt32.max) else { return 0 }
        let unwrapped = (UInt64(UInt32.max) - previous) + current + 1

        // A genuine reset can masquerade as a wrap. Reject anything implying a
        // rate no consumer link could produce (100 Gbit/s ≈ 12.5 GB/s).
        let implausible = Double(unwrapped) / elapsed > 12_500_000_000
        return implausible ? 0 : unwrapped
    }

    /// Flips only when the other direction is clearly busier, so the menu bar
    /// arrow does not strobe back and forth on near-equal traffic.
    private func updateDominantDirection() {
        let margin = 1.3
        let floor = 1024.0   // below this both directions are just chatter

        switch dominantDirection {
        case .download:
            if upload > floor, upload > download * margin { dominantDirection = .upload }
        case .upload:
            if download > upload * margin || upload < floor { dominantDirection = .download }
        }
    }

    /// Sums the interfaces that look like real hardware, skipping loopback,
    /// bridges, and awdl/llw (AirDrop and friends) which are not internet paths.
    private static func sumPhysical(_ counters: [String: InterfaceCounters]) -> InterfaceCounters {
        let ignoredPrefixes = ["lo", "gif", "stf", "bridge", "awdl", "llw", "ap", "utun", "anpi"]
        return counters
            .filter { name, _ in !ignoredPrefixes.contains { name.hasPrefix($0) } }
            .values
            .reduce(into: InterfaceCounters.zero) { total, item in
                total.bytesIn += item.bytesIn
                total.bytesOut += item.bytesOut
            }
    }
}
