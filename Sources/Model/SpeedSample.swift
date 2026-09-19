import Foundation

/// One tick of measured throughput, in bytes per second.
struct SpeedSample: Identifiable, Equatable, Sendable {
    let id = UUID()
    let timestamp: Date
    let download: Double
    let upload: Double

    static let zero = SpeedSample(timestamp: .distantPast, download: 0, upload: 0)
}
