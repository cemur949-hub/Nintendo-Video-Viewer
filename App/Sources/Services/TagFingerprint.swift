import CryptoKit
import Foundation

/// Tags are stored as a SHA-256 of their UID, never the raw UID.
enum TagFingerprint {
    static func make(from identifier: Data) -> String {
        SHA256.hash(data: identifier).map { String(format: "%02x", $0) }.joined()
    }
}
