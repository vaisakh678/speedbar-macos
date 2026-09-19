import Darwin
import Foundation

/// Reads the IP address the system has assigned to a given interface.
///
/// This is the LAN address (`192.168.x.x`), not the address the internet sees
/// — that one requires asking an outside party, which `PublicAddressLookup`
/// does only when the user explicitly requests it.
enum LocalAddressReader {

    /// IPv4 for `interface` when it has one, else a routable IPv6. Link-local
    /// IPv6 (`fe80::…`) is skipped: it is never the address someone wants to
    /// copy, and every interface has one.
    static func address(for interface: String) -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let head else { return nil }
        defer { freeifaddrs(head) }

        var ipv4: String?
        var ipv6: String?

        for entry in sequence(first: head, next: { $0.pointee.ifa_next }) {
            let record = entry.pointee
            guard let rawName = record.ifa_name,
                  String(cString: rawName) == interface,
                  let addr = record.ifa_addr else { continue }

            let family = addr.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }

            var text = String(cBuffer: host)

            if family == UInt8(AF_INET) {
                if ipv4 == nil { ipv4 = text }
            } else {
                // Trim the scope suffix that IPv6 carries on link-local
                // addresses, e.g. "fe80::1cd2:9a1%en0".
                if let zone = text.firstIndex(of: "%") { text = String(text[..<zone]) }
                if !text.hasPrefix("fe80"), ipv6 == nil { ipv6 = text }
            }
        }

        return ipv4 ?? ipv6
    }
}
