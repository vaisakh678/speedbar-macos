import Foundation

/// Whether rates are shown the way a file manager counts (bytes) or the way an
/// ISP advertises (bits). Both are in common use, so it is a user setting.
enum RateUnit: String, CaseIterable, Identifiable, Sendable {
    case bytes
    case bits

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bytes: "Bytes (MB/s)"
        case .bits: "Bits (Mbps)"
        }
    }
}

enum RateFormatter {

    /// Formats a bytes-per-second rate into a compact `value`/`unit` pair, kept
    /// separate so the menu bar can align the number and unit independently.
    static func components(bytesPerSecond: Double, as unit: RateUnit) -> (value: String, unit: String) {
        switch unit {
        case .bytes:
            // Storage convention: 1 KB = 1024 B.
            return scale(bytesPerSecond, divisor: 1024, suffixes: ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"])
        case .bits:
            // Networking convention: 1 kb = 1000 b.
            return scale(bytesPerSecond * 8, divisor: 1000, suffixes: ["bps", "Kbps", "Mbps", "Gbps", "Tbps"])
        }
    }

    /// A deliberately terse form for the menu bar: `1.2` + `M`, with the
    /// per-second sense carried by the arrow glyph beside it. The menu bar is
    /// contested space — on a notched display a full `12.4 MB/s` per row is
    /// wide enough that macOS banishes the whole item to the overflow menu.
    static func compactComponents(bytesPerSecond: Double, as unit: RateUnit) -> (value: String, unit: String) {
        switch unit {
        case .bytes:
            return scale(bytesPerSecond, divisor: 1024, suffixes: ["", "K", "M", "G", "T"])
        case .bits:
            return scale(bytesPerSecond * 8, divisor: 1000, suffixes: ["", "K", "M", "G", "T"])
        }
    }

    static func string(bytesPerSecond: Double, as unit: RateUnit) -> String {
        let parts = components(bytesPerSecond: bytesPerSecond, as: unit)
        return "\(parts.value) \(parts.unit)"
    }

    /// Formats a cumulative byte total (session usage), always in bytes.
    static func totalString(bytes: UInt64) -> String {
        let parts = scale(Double(bytes), divisor: 1024, suffixes: ["B", "KB", "MB", "GB", "TB"])
        return "\(parts.value) \(parts.unit)"
    }

    private static func scale(_ amount: Double, divisor: Double, suffixes: [String]) -> (value: String, unit: String) {
        guard amount.isFinite, amount > 0 else { return ("0", suffixes[0]) }

        var value = amount
        var index = 0
        while value >= divisor, index < suffixes.count - 1 {
            value /= divisor
            index += 1
        }

        // Keep the digit count roughly constant so the menu bar text does not
        // jitter in width as the rate changes.
        let decimals: Int = if index == 0 { 0 } else if value < 10 { 1 } else { 0 }
        return (String(format: "%.\(decimals)f", value), suffixes[index])
    }
}
