import Foundation

extension String {
    /// Builds a `String` from a NUL-terminated C character buffer.
    ///
    /// `String(cString:)` is deprecated for array arguments. Its replacement,
    /// `String(decoding:as:)`, decodes the whole array — so the NUL and any
    /// trailing garbage have to be dropped first, and `CChar` (signed)
    /// reinterpreted as the unsigned bytes UTF8 expects.
    init(cBuffer: [CChar]) {
        let bytes = cBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        self.init(decoding: bytes, as: UTF8.self)
    }
}
