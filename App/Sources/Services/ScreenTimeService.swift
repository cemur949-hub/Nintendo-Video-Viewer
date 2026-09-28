import DeviceActivity
import FamilyControls

/// Wraps the Family Controls and DeviceActivity calls the app makes.
/// Only call these when `CapabilityReport.canBlockApps` is true (authorization excepted).
enum ScreenTimeService {
    static func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    /// Starts the daily schedule. The DeviceActivityMonitor extension adds and removes the shield.
    static func startMonitoring(_ schedule: LockSchedule) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.schedule])
        try center.startMonitoring(
            .schedule,
            during: DeviceActivitySchedule(intervalStart: schedule.start, intervalEnd: schedule.end, repeats: true)
        )
    }

    static func stopMonitoring() {
        DeviceActivityCenter().stopMonitoring([.schedule])
        ShieldController.clear(.schedule)
    }
}
