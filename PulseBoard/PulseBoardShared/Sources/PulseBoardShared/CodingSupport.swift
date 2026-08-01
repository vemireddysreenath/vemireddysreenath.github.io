import Foundation

extension JSONEncoder {
    /// Shared encoder for all PulseBoard wire/storage formats (WatchConnectivity
    /// payloads and on-disk caches). `.secondsSince1970` avoids ISO8601
    /// formatting/timezone edge cases for device-to-device transfer.
    public static var pulseBoard: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}

extension JSONDecoder {
    public static var pulseBoard: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
