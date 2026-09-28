import Foundation

/// An NFC tag registered as a key.
struct RegisteredTag: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// SHA-256 of the tag's hardware identifier, hex-encoded. The raw UID is never stored.
    var fingerprint: String
    var addedAt: Date
}

/// A daily lock window, enforced by the DeviceActivityMonitor extension.
struct LockSchedule: Codable, Equatable {
    var isEnabled: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    static let `default` = LockSchedule(isEnabled: false, startHour: 22, startMinute: 0, endHour: 7, endMinute: 0)

    var start: DateComponents { DateComponents(hour: startHour, minute: startMinute) }
    var end: DateComponents { DateComponents(hour: endHour, minute: endMinute) }

    /// Length of the window in minutes. Windows may cross midnight.
    var durationMinutes: Int {
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        return (end - start + 24 * 60) % (24 * 60)
    }

    /// DeviceActivity rejects intervals shorter than 15 minutes.
    var isValid: Bool { durationMinutes >= 15 }
}

/// Text shown on the block screen by the ShieldConfiguration extension.
struct ShieldText: Codable, Equatable {
    var title: String
    var message: String

    static let `default` = ShieldText(
        title: "Locked",
        message: "Scan your NFC tag in the app to unlock."
    )
}
