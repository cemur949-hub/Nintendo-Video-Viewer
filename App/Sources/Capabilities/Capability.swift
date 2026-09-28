import SwiftUI

enum CapabilityKind: String, CaseIterable, Identifiable {
    case familyControls, nfc, appGroup, extensions, notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .familyControls: return "Screen Time (Family Controls)"
        case .nfc: return "NFC tag reading"
        case .appGroup: return "App Group"
        case .extensions: return "App extensions"
        case .notifications: return "Notifications"
        }
    }

    /// The message shown to the user for each state.
    func message(for status: CapabilityStatus) -> String {
        switch (self, status) {
        case (_, .ready):
            return "Available."
        case (_, .unknown):
            return "Couldn't be checked for this build. The app will try, and report any error."
        case (_, .unsupported(let reason)):
            return reason

        case (.familyControls, .stripped):
            return "The Family Controls entitlement was removed when this copy was signed. Free Apple IDs can't get it, and SideStore can't add it. App blocking and schedules are off; the rest of the app still works. To block apps, sign with a paid developer account (see docs/ENTITLEMENTS.md)."
        case (.familyControls, .needsPermission):
            return "Allow Screen Time access so the app can block the apps you choose."
        case (.familyControls, .denied):
            return "Screen Time access is turned off for this app. Turn it back on in Settings to block apps."

        case (.nfc, .stripped):
            return "The NFC Tag Reading entitlement was removed when this copy was signed, because free Apple IDs can't get it. Tags can't be scanned. Unlock with Emergency unlock instead, or sign with a paid developer account."

        case (.appGroup, .stripped):
            return "No App Group was granted when this copy was signed, so the extensions can't read your block list, schedule or block-screen text. Lock now and unlock still work. Scheduled locks and custom block-screen text don't."

        case (.extensions, .stripped):
            let missing = ExtensionInventory.missing().map(\.purpose).joined(separator: ", ")
            return "This copy was installed without some of its app extensions (\(missing)). SideStore can remove them to save App IDs. Reinstall and keep the extensions to use these features."

        case (.notifications, .needsPermission):
            return "Allow notifications for schedule alerts and a reminder to refresh in SideStore before the app expires."
        case (.notifications, .denied):
            return "Notifications are off, so you won't get a reminder to refresh in SideStore before the app expires."

        default:
            return "Unavailable."
        }
    }
}

enum CapabilityStatus: Equatable {
    case ready
    case needsPermission
    case denied
    /// The entitlement (or App Group, or extension) was removed when the app was signed.
    case stripped
    case unsupported(String)
    case unknown

    /// Whether the feature can be attempted. Unknown gets a try, with errors handled.
    var isUsable: Bool {
        switch self {
        case .ready, .unknown: return true
        default: return false
        }
    }

    var needsAttention: Bool {
        switch self {
        case .ready, .unknown: return false
        default: return true
        }
    }

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .needsPermission: return "Needs permission"
        case .denied: return "Turned off"
        case .stripped: return "Stripped at signing"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        }
    }

    var symbol: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .needsPermission: return "questionmark.circle.fill"
        case .denied: return "hand.raised.circle.fill"
        case .stripped: return "xmark.octagon.fill"
        case .unsupported: return "slash.circle.fill"
        case .unknown: return "circle.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return .green
        case .needsPermission: return .orange
        case .denied, .unsupported: return .secondary
        case .stripped: return .red
        case .unknown: return .secondary
        }
    }
}

struct CapabilityReport: Equatable {
    private var statuses: [CapabilityKind: CapabilityStatus] = [:]

    subscript(kind: CapabilityKind) -> CapabilityStatus {
        get { statuses[kind] ?? .unknown }
        set { statuses[kind] = newValue }
    }

    var issues: [CapabilityKind] { CapabilityKind.allCases.filter { self[$0].needsAttention } }

    /// Family Controls calls are made only when this is true.
    var canBlockApps: Bool { self[.familyControls] == .ready }
}
