import FamilyControls
import SwiftUI
import UIKit

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// App state and actions. Every Family Controls or NFC call checks
/// `report` first. If an entitlement was stripped at signing, the user gets an
/// explanation instead of a crash or a silent failure.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var report = CapabilityReport()
    @Published private(set) var isLocked = false
    @Published private(set) var lockedAt: Date?
    @Published private(set) var isScheduleActive = false
    @Published private(set) var selection = FamilyActivitySelection()
    @Published private(set) var tags: [RegisteredTag] = []
    @Published private(set) var schedule = LockSchedule.default
    @Published private(set) var notificationsEnabled = true
    @Published private(set) var currentIcon = AppIcon.standard
    @Published private(set) var isScanning = false
    @Published var alert: AppAlert?

    @Published var shieldText = ShieldText.default {
        didSet { store.shieldText = shieldText }
    }

    @Published var emergencyUnlockDelay = 30 {
        didSet { store.emergencyUnlockDelay = emergencyUnlockDelay }
    }

    private let store = SharedStore.shared
    private let scanner = NFCTagScanner()

    init() {
        reloadFromStore()
        shieldText = store.shieldText
        emergencyUnlockDelay = store.emergencyUnlockDelay
    }

    // MARK: Derived state

    /// Locked by "Lock now", or by a schedule window that's running now.
    var isEffectivelyLocked: Bool { isLocked || isScheduleActive }

    var canLock: Bool { report.canBlockApps && !selection.blocksNothing }

    var canScanTags: Bool { report[.nfc].isUsable && !isScanning }

    var canUnlockWithTag: Bool { canScanTags && !tags.isEmpty }

    var canSchedule: Bool {
        report.canBlockApps && report[.extensions] == .ready && report[.appGroup] == .ready
    }

    var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        if apps + categories + sites == 0 { return "Nothing selected" }
        return "\(apps) apps · \(categories) categories · \(sites) websites"
    }

    // MARK: Refresh

    func refresh() async {
        reloadFromStore()
        report = await CapabilityInspector.inspect()
        currentIcon = AppIcon.current
        updateRefreshReminders()
    }

    private func reloadFromStore() {
        isLocked = store.isLocked
        lockedAt = store.lockedAt
        isScheduleActive = store.isScheduleActive
        selection = store.selection
        tags = store.registeredTags
        schedule = store.schedule
        notificationsEnabled = store.notificationsEnabled
    }

    // MARK: Screen Time

    func requestScreenTimeAccess() async {
        guard report[.familyControls] != .stripped else {
            show("Screen Time unavailable", CapabilityKind.familyControls.message(for: .stripped))
            return
        }
        do {
            try await ScreenTimeService.requestAuthorization()
        } catch {
            show("Screen Time access not granted", "\(error.localizedDescription)\n\nIf this keeps happening, open Diagnostics to check whether the Family Controls entitlement survived signing.")
        }
        await refresh()
    }

    func updateSelection(_ newSelection: FamilyActivitySelection) {
        guard report.canBlockApps else { return }
        selection = newSelection
        store.selection = newSelection
        if isLocked { ShieldController.apply(newSelection, to: .manual) }
        if isScheduleActive { ShieldController.apply(newSelection, to: .schedule) }
    }

    // MARK: Lock / unlock

    func lock() {
        guard report.canBlockApps else {
            show("Can't lock", CapabilityKind.familyControls.message(for: report[.familyControls]))
            return
        }
        guard !selection.blocksNothing else {
            show("Nothing to block", "Choose the apps, categories or websites to block first.")
            return
        }
        ShieldController.apply(selection, to: .manual)
        store.isLocked = true
        store.lockedAt = Date()
        reloadFromStore()
    }

    func unlockWithTag() async {
        guard !tags.isEmpty else {
            show("No tags registered", "Register an NFC tag first, or use Emergency unlock.")
            return
        }
        guard let fingerprint = await scanFingerprint(prompt: "Hold your iPhone near your tag to unlock.") else { return }
        guard tags.contains(where: { $0.fingerprint == fingerprint }) else {
            show("Unknown tag", "That tag isn't registered as a key.")
            return
        }
        unlock()
    }

    func emergencyUnlock() {
        unlock()
    }

    /// Clears the manual shield and any running scheduled shield. The schedule comes back at its next start time.
    private func unlock() {
        if report[.familyControls] != .stripped {
            ShieldController.clear(.manual)
            ShieldController.clear(.schedule)
        }
        store.isLocked = false
        store.lockedAt = nil
        store.isScheduleActive = false
        reloadFromStore()
    }

    // MARK: Tags

    func registerTag(named name: String) async {
        guard let fingerprint = await scanFingerprint(prompt: "Hold your iPhone near the tag you want to use as a key.") else { return }
        guard !tags.contains(where: { $0.fingerprint == fingerprint }) else {
            show("Already registered", "That tag is already one of your keys.")
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tags.append(RegisteredTag(
            id: UUID(),
            name: trimmed.isEmpty ? "Tag \(tags.count + 1)" : trimmed,
            fingerprint: fingerprint,
            addedAt: Date()
        ))
        store.registeredTags = tags
    }

    func removeTags(at offsets: IndexSet) {
        guard !isEffectivelyLocked else { return }
        tags.remove(atOffsets: offsets)
        store.registeredTags = tags
    }

    private func scanFingerprint(prompt: String) async -> String? {
        let status = report[.nfc]
        guard status.isUsable else {
            show("Can't scan tags", CapabilityKind.nfc.message(for: status))
            return nil
        }

        isScanning = true
        defer { isScanning = false }
        do {
            let identifier = try await scanner.scan(prompt: prompt)
            return TagFingerprint.make(from: identifier)
        } catch NFCTagScanner.ScanError.cancelled {
            return nil
        } catch NFCTagScanner.ScanError.entitlementMissing {
            report[.nfc] = .stripped
            show("NFC unavailable", CapabilityKind.nfc.message(for: .stripped))
            return nil
        } catch {
            show("Couldn't read tag", error.localizedDescription)
            return nil
        }
    }

    // MARK: Schedule

    func setScheduleEnabled(_ enabled: Bool) {
        var updated = schedule
        updated.isEnabled = enabled
        applySchedule(updated)
    }

    func setScheduleTimes(start: Date? = nil, end: Date? = nil) {
        var updated = schedule
        if let start { (updated.startHour, updated.startMinute) = Self.hourAndMinute(of: start) }
        if let end { (updated.endHour, updated.endMinute) = Self.hourAndMinute(of: end) }
        applySchedule(updated)
    }

    private func applySchedule(_ updated: LockSchedule) {
        if updated.isEnabled {
            if let reason = scheduleUnavailableReason {
                show("Schedules unavailable", reason)
                return
            }
            guard updated.isValid else {
                show("Schedule too short", "A scheduled lock has to last at least 15 minutes.")
                return
            }
            do {
                try ScreenTimeService.startMonitoring(updated)
            } catch {
                show("Couldn't start the schedule", error.localizedDescription)
                return
            }
        } else if schedule.isEnabled, report.canBlockApps {
            ScreenTimeService.stopMonitoring()
            store.isScheduleActive = false
        }
        store.schedule = updated
        reloadFromStore()
    }

    private var scheduleUnavailableReason: String? {
        if !report.canBlockApps { return CapabilityKind.familyControls.message(for: report[.familyControls]) }
        if report[.extensions] != .ready { return CapabilityKind.extensions.message(for: report[.extensions]) }
        if report[.appGroup] != .ready { return CapabilityKind.appGroup.message(for: report[.appGroup]) }
        return nil
    }

    private static func hourAndMinute(of date: Date) -> (Int, Int) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0, parts.minute ?? 0)
    }

    // MARK: Notifications

    func setNotificationsEnabled(_ enabled: Bool) async {
        notificationsEnabled = enabled
        store.notificationsEnabled = enabled
        if enabled, report[.notifications] == .needsPermission {
            _ = await NotificationService.requestAuthorization()
        }
        report[.notifications] = await CapabilityInspector.notificationStatus()
        updateRefreshReminders()
    }

    private func updateRefreshReminders() {
        if notificationsEnabled, report[.notifications] == .ready,
           let expiry = ProvisioningProfile.embedded?.expirationDate {
            NotificationService.scheduleRefreshReminders(expiry: expiry)
        } else {
            NotificationService.cancelRefreshReminders()
        }
    }

    // MARK: App icon

    func setIcon(_ icon: AppIcon) {
        guard UIApplication.shared.supportsAlternateIcons else {
            show("Icons unavailable", "This device doesn't support alternate app icons.")
            return
        }
        guard icon != currentIcon else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
            } catch {
                show("Couldn't change icon", error.localizedDescription)
            }
            currentIcon = AppIcon.current
        }
    }

    // MARK: Misc

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func show(_ title: String, _ message: String) {
        alert = AppAlert(title: title, message: message)
    }
}
