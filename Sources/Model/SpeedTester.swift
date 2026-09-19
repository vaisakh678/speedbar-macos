import Foundation
import Observation

/// On-demand throughput test against Cloudflare's public speed endpoints.
///
/// This is deliberately a rough measure, not an Ookla replacement: one stream
/// per direction, no server selection, no multi-connection ramp-up. It answers
/// "roughly how fast is this link right now", which is what the panel needs.
@MainActor
@Observable
final class SpeedTester {

    enum Phase: Equatable {
        case idle
        case latency
        case download
        case upload
        case finished
        case failed(String)
    }

    struct Result: Equatable {
        var downloadBytesPerSecond: Double
        var uploadBytesPerSecond: Double
        var latency: Duration
    }

    private(set) var phase: Phase = .idle
    private(set) var result: Result?
    /// Live rate while a test is running, so the gauge can move during the run.
    private(set) var liveRate: Double = 0

    var isRunning: Bool {
        switch phase {
        case .latency, .download, .upload: true
        default: false
        }
    }

    private static let downloadBytes = 25_000_000
    private static let uploadBytes = 8_000_000
    private static let host = "https://speed.cloudflare.com"

    private var task: Task<Void, Never>?
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        // Never let a cache serve the payload — that would measure disk speed.
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }

    func run() {
        guard !isRunning else { return }
        task?.cancel()
        result = nil
        liveRate = 0

        task = Task { [weak self] in
            guard let self else { return }
            do {
                self.phase = .latency
                let latency = try await self.measureLatency()

                self.phase = .download
                let down = try await self.measureDownload()

                self.phase = .upload
                let up = try await self.measureUpload()

                self.liveRate = 0
                self.result = Result(downloadBytesPerSecond: down, uploadBytesPerSecond: up, latency: latency)
                self.phase = .finished
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.liveRate = 0
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        liveRate = 0
        phase = .idle
    }

    /// Median round-trip of a few tiny requests, which is less noisy than one.
    private func measureLatency() async throws -> Duration {
        var samples: [Duration] = []
        for _ in 0..<5 {
            try Task.checkCancellation()
            let url = URL(string: "\(Self.host)/__down?bytes=0")!
            let clock = ContinuousClock()
            let start = clock.now
            _ = try await session.data(from: url)
            samples.append(clock.now - start)
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    private func measureDownload() async throws -> Double {
        let url = URL(string: "\(Self.host)/__down?bytes=\(Self.downloadBytes)")!
        let (stream, _) = try await session.bytes(from: url)

        let clock = ContinuousClock()
        // Start the clock at the first byte so connection setup does not count
        // against the measured throughput.
        var start: ContinuousClock.Instant?
        var received = 0
        var lastReport = clock.now

        for try await _ in stream {
            if start == nil { start = clock.now }
            received += 1

            let now = clock.now
            if now - lastReport > .milliseconds(150), let start {
                let seconds = Double((now - start).components.seconds)
                    + Double((now - start).components.attoseconds) / 1e18
                if seconds > 0 { liveRate = Double(received) / seconds }
                lastReport = now
            }
        }

        guard let start, received > 0 else { return 0 }
        let elapsed = clock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        guard seconds > 0 else { return 0 }
        return Double(received) / seconds
    }

    private func measureUpload() async throws -> Double {
        let url = URL(string: "\(Self.host)/__up")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let payload = Data(count: Self.uploadBytes)
        let clock = ContinuousClock()
        let start = clock.now
        _ = try await session.upload(for: request, from: payload)
        let elapsed = clock.now - start

        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        guard seconds > 0 else { return 0 }
        return Double(Self.uploadBytes) / seconds
    }
}
