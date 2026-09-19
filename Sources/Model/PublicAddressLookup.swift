import Foundation
import Observation

/// Finds the address the internet sees, by reading the `cf-meta-ip` header
/// Cloudflare attaches to its speed-test responses.
///
/// Runs only when the user asks. Opening the menu must not quietly tell an
/// outside service where you are, and the app already reaches
/// `speed.cloudflare.com` for the speed test — so this adds no new third party.
@MainActor
@Observable
final class PublicAddressLookup {

    enum State: Equatable {
        case idle
        case looking
        case found(String)
        case failed
    }

    private(set) var state: State = .idle

    private static let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
    private var task: Task<Void, Never>?

    /// A lookup parked in a fixed state, for previews and screenshots.
    static func preview(state: State) -> PublicAddressLookup {
        let lookup = PublicAddressLookup()
        lookup.state = state
        return lookup
    }

    /// Discards a cached result, so the next lookup reflects a new network.
    func invalidate() {
        task?.cancel()
        task = nil
        state = .idle
    }

    func lookUp() {
        guard state != .looking else { return }
        task?.cancel()
        state = .looking

        task = Task { [weak self] in
            guard let self else { return }

            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.timeoutIntervalForRequest = 10
            let session = URLSession(configuration: configuration)

            do {
                let (_, response) = try await session.data(from: Self.url)
                guard let http = response as? HTTPURLResponse,
                      let address = http.value(forHTTPHeaderField: "cf-meta-ip"),
                      !address.isEmpty else {
                    self.state = .failed
                    return
                }
                self.state = .found(address)
            } catch is CancellationError {
                self.state = .idle
            } catch {
                self.state = .failed
            }
        }
    }
}
