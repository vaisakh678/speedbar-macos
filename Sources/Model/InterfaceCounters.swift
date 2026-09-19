import Darwin
import Foundation

/// Cumulative byte counters the kernel keeps for a single network interface.
struct InterfaceCounters: Sendable, Equatable {
    var bytesIn: UInt64
    var bytesOut: UInt64

    static let zero = InterfaceCounters(bytesIn: 0, bytesOut: 0)
}

/// Reads per-interface traffic counters straight from the routing socket via
/// `sysctl(NET_RT_IFLIST2)`.
///
/// `NET_RT_IFLIST2` returns `if_msghdr2`, whose embedded `if_data64` declares
/// `ifi_ibytes`/`ifi_obytes` as `u_int64_t` — but do not trust the width.
///
/// Verified against `netstat -ib` on macOS 27: the kernel populates those
/// fields from a 32-bit counter, so the value observed here wraps at 2^32
/// while netstat reports the accumulated total (our 3_279_017_984 vs netstat's
/// 29_048_821_735 — exactly 6 wraps apart). A byte-by-byte scan of the whole
/// 180-byte record found no untruncated copy of the value anywhere, so there
/// is nothing better to read.
///
/// Callers must therefore treat a counter going backwards as a wrap, not as a
/// reset — see `SpeedMonitor.delta(from:to:)`.
enum InterfaceCountersReader {

    /// Snapshot of every interface the kernel knows about, keyed by BSD name
    /// (`en0`, `utun4`, `lo0`, …). Returns an empty dictionary if the kernel
    /// query fails, which callers treat as "no new data this tick".
    static func readAll() -> [String: InterfaceCounters] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]

        // First pass sizes the buffer, second pass fills it. The table can grow
        // between the two calls (an interface appearing), so pad it a little.
        var needed = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &needed, nil, 0) == 0, needed > 0 else {
            return [:]
        }

        var buffer = [UInt8](repeating: 0, count: needed + 1024)
        var written = buffer.count
        let status = buffer.withUnsafeMutableBytes { raw in
            sysctl(&mib, UInt32(mib.count), raw.baseAddress, &written, nil, 0)
        }
        guard status == 0, written > 0 else { return [:] }

        return parse(buffer: buffer, byteCount: min(written, buffer.count))
    }

    /// Walks the packed array of variable-length routing messages, picking out
    /// the `RTM_IFINFO2` records and ignoring everything else (address records,
    /// older `RTM_IFINFO` entries).
    private static func parse(buffer: [UInt8], byteCount: Int) -> [String: InterfaceCounters] {
        var result: [String: InterfaceCounters] = [:]

        buffer.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0

            while offset + MemoryLayout<if_msghdr>.size <= byteCount {
                // The messages are packed without padding, so every field has to
                // be read unaligned.
                let header = (base + offset).loadUnaligned(as: if_msghdr.self)
                let messageLength = Int(header.ifm_msglen)

                // A zero or negative length would spin forever; bail out instead.
                guard messageLength > 0, offset + messageLength <= byteCount else { break }

                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= byteCount {
                    let info = (base + offset).loadUnaligned(as: if_msghdr2.self)
                    if let name = interfaceName(forIndex: UInt32(info.ifm_index)) {
                        result[name] = InterfaceCounters(
                            bytesIn: info.ifm_data.ifi_ibytes,
                            bytesOut: info.ifm_data.ifi_obytes
                        )
                    }
                }

                offset += messageLength
            }
        }

        return result
    }

    private static func interfaceName(forIndex index: UInt32) -> String? {
        var storage = [CChar](repeating: 0, count: Int(IFNAMSIZ) + 1)
        guard if_indextoname(index, &storage) != nil else { return nil }
        return String(cString: storage)
    }
}
