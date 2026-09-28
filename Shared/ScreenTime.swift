import DeviceActivity
import FamilyControls
import ManagedSettings

// Screen Time code shared by the app and the DeviceActivityMonitor extension.
// Every call here needs the Family Controls entitlement. The app checks for it
// before calling (see CapabilityInspector). Without the entitlement, iOS never
// launches the extension.

extension ManagedSettingsStore.Name {
    /// Shields added by "Lock now". Removed by a tag scan or an emergency unlock.
    static let manual = Self("manual")
    /// Shields added by the schedule. Removed when the window ends.
    static let schedule = Self("schedule")
}

extension DeviceActivityName {
    static let schedule = Self("schedule")
}

extension FamilyActivitySelection {
    var blocksNothing: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }
}

extension SharedStore {
    /// The apps, categories and websites to shield.
    var selection: FamilyActivitySelection {
        get { decode(FamilyActivitySelection.self, for: .selection) ?? FamilyActivitySelection() }
        set { encode(newValue, for: .selection) }
    }
}

enum ShieldController {
    static func apply(_ selection: FamilyActivitySelection, to name: ManagedSettingsStore.Name) {
        let store = ManagedSettingsStore(named: name)
        let categories = selection.categoryTokens
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = categories.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy<Application>.specific(categories)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = categories.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy<WebDomain>.specific(categories)
        Log.shield.info("Applied shield to store \(String(describing: name), privacy: .public)")
    }

    static func clear(_ name: ManagedSettingsStore.Name) {
        ManagedSettingsStore(named: name).clearAllSettings()
        Log.shield.info("Cleared shield store \(String(describing: name), privacy: .public)")
    }
}
