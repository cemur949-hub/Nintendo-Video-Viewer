import CoreNFC
import FamilyControls
import UserNotifications

/// Builds a `CapabilityReport` without calling any API that needs a missing entitlement.
enum CapabilityInspector {
    @MainActor
    static func inspect() async -> CapabilityReport {
        var report = CapabilityReport()
        report[.familyControls] = familyControlsStatus()
        report[.nfc] = nfcStatus()
        report[.appGroup] = AppGroup.isAvailable ? .ready : .stripped
        report[.extensions] = ExtensionInventory.missing().isEmpty ? .ready : .stripped
        report[.notifications] = await notificationStatus()

        for kind in report.issues {
            let label = report[kind].label
            Log.signing.notice("\(kind.rawValue, privacy: .public): \(label, privacy: .public)")
        }
        return report
    }

    @MainActor
    private static func familyControlsStatus() -> CapabilityStatus {
        // Don't touch AuthorizationCenter if the entitlement is missing.
        if Entitlements.familyControls == .missing { return .stripped }
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return .ready
        case .denied: return .denied
        case .notDetermined: return .needsPermission
        @unknown default: return .unknown
        }
    }

    private static func nfcStatus() -> CapabilityStatus {
        #if targetEnvironment(simulator)
        return .unsupported("The Simulator has no NFC reader. Use a real iPhone.")
        #else
        if Entitlements.nfcTagReading == .missing { return .stripped }
        return NFCTagReaderSession.readingAvailable
            ? .ready
            : .unsupported("This device can't read NFC tags. Use Emergency unlock instead.")
        #endif
    }

    static func notificationStatus() async -> CapabilityStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .ready
        case .denied: return .denied
        case .notDetermined: return .needsPermission
        @unknown default: return .unknown
        }
    }
}
