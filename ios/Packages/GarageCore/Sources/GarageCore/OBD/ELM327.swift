import Foundation

/// Text parsing for ELM327-style adapters (the command set OBDLink, vLinker and
/// Veepeak dongles all speak). Pure functions, so the Bluetooth source and the
/// simulator share one tested decode path.
public enum ELM327 {
    /// Pulls the hex bytes out of one reply line. With headers switched on, a
    /// line starts with a 3-digit CAN address such as "7E8"; it is dropped,
    /// because its odd length would otherwise shift every byte after it.
    static func hexBytes(in line: String) -> [UInt8] {
        var tokens = line.uppercased().split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count > 1, tokens[0].count == 3 { tokens.removeFirst() }
        var cleaned = tokens.joined().filter(\.isHexDigit)
        // The same header when the adapter has spaces switched off.
        if cleaned.count % 2 == 1 { cleaned.removeFirst(min(3, cleaned.count)) }

        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        while let next = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) {
            if let byte = UInt8(cleaned[index..<next], radix: 16) { bytes.append(byte) }
            index = next
        }
        return bytes
    }

    /// Reads a live-data reply such as "41 0C 1A F8" (or "7E8 04 41 0C 1A F8"
    /// with headers on) for the given PID. Nil for "NO DATA", errors or a reply to something else.
    public static func parseLiveData(_ reply: String, for pid: OBDPID) -> Double? {
        for line in reply.split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, text.allSatisfy({ $0.isHexDigit || $0 == " " }) else { continue }
            let bytes = hexBytes(in: text)
            // Find the "41 <pid>" marker; anything before it is a CAN header and length byte.
            guard let marker = zip(bytes.indices, zip(bytes, bytes.dropFirst()))
                .first(where: { $0.1.0 == 0x41 && $0.1.1 == pid.rawValue })?.0
            else { continue }
            let data = Array(bytes[(marker + 2)...])
            if let value = pid.decode(data) { return value }
        }
        return nil
    }

    /// Reads a stored-codes reply (service 03), such as "43 01 33 00 00 00 00".
    /// Zero pairs are padding and are skipped. Handles one line per responding module.
    public static func parseTroubleCodes(_ reply: String) -> [String] {
        var codes: [String] = []
        for line in reply.split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, text.allSatisfy({ $0.isHexDigit || $0 == " " }) else { continue }
            let bytes = hexBytes(in: text)
            guard let marker = bytes.firstIndex(of: 0x43) else { continue }
            var payload = Array(bytes[(marker + 1)...])
            // CAN replies put a code count first, which leaves an odd number of bytes.
            if payload.count % 2 == 1 { payload.removeFirst() }
            for pair in stride(from: 0, to: payload.count - 1, by: 2) {
                let code = troubleCode(payload[pair], payload[pair + 1])
                if let code, !codes.contains(code) { codes.append(code) }
            }
        }
        return codes
    }

    /// Two bytes to a code like "P0133". Nil for the all-zero padding pair.
    public static func troubleCode(_ first: UInt8, _ second: UInt8) -> String? {
        guard first != 0 || second != 0 else { return nil }
        let system = ["P", "C", "B", "U"][Int(first >> 6)]
        return String(format: "%@%X%X%02X", system, (first >> 4) & 0x3, first & 0xF, second)
    }

    /// The reverse of `troubleCode`, for the simulator.
    static func bytes(forTroubleCode code: String) -> (UInt8, UInt8)? {
        let text = code.uppercased()
        guard text.count == 5, let system = ["P", "C", "B", "U"].firstIndex(of: String(text.prefix(1))),
              let value = UInt16(text.dropFirst(), radix: 16), value >> 12 <= 3
        else { return nil }
        let word = UInt16(system) << 14 | value
        return (UInt8(word >> 8), UInt8(word & 0xFF))
    }
}
