import Foundation

/// Settings shared between the app and its extensions through the App Group.
///
/// If App Groups were stripped at signing, this falls back to the app's own
/// defaults. The app keeps working, but the extensions can't see the data.
/// `isShared` tells you which one you got.
final class SharedStore {
    static let shared = SharedStore()

    let defaults: UserDefaults
    let isShared: Bool

    private init() {
        if let group = AppGroup.identifier, let groupDefaults = UserDefaults(suiteName: group) {
            defaults = groupDefaults
            isShared = true
        } else {
            defaults = .standard
            isShared = false
        }
    }

    enum Key: String {
        case isLocked, lockedAt, isScheduleActive, selection, registeredTags, schedule
        case shieldText, notificationsEnabled, emergencyUnlockDelay
    }

    var isLocked: Bool {
        get { defaults.bool(forKey: Key.isLocked.rawValue) }
        set { defaults.set(newValue, forKey: Key.isLocked.rawValue) }
    }

    var lockedAt: Date? {
        get { defaults.object(forKey: Key.lockedAt.rawValue) as? Date }
        set { defaults.set(newValue, forKey: Key.lockedAt.rawValue) }
    }

    /// Set by the DeviceActivityMonitor extension while a scheduled window is running.
    var isScheduleActive: Bool {
        get { defaults.bool(forKey: Key.isScheduleActive.rawValue) }
        set { defaults.set(newValue, forKey: Key.isScheduleActive.rawValue) }
    }

    var registeredTags: [RegisteredTag] {
        get { decode([RegisteredTag].self, for: .registeredTags) ?? [] }
        set { encode(newValue, for: .registeredTags) }
    }

    var schedule: LockSchedule {
        get { decode(LockSchedule.self, for: .schedule) ?? .default }
        set { encode(newValue, for: .schedule) }
    }

    var shieldText: ShieldText {
        get { decode(ShieldText.self, for: .shieldText) ?? .default }
        set { encode(newValue, for: .shieldText) }
    }

    var notificationsEnabled: Bool {
        get { defaults.object(forKey: Key.notificationsEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled.rawValue) }
    }

    /// Seconds the emergency unlock makes you wait.
    var emergencyUnlockDelay: Int {
        get { defaults.object(forKey: Key.emergencyUnlockDelay.rawValue) as? Int ?? 30 }
        set { defaults.set(newValue, forKey: Key.emergencyUnlockDelay.rawValue) }
    }

    func decode<T: Decodable>(_ type: T.Type, for key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func encode<T: Encodable>(_ value: T, for key: Key) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }
}
