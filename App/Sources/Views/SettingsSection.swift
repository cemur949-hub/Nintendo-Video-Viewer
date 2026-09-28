import SwiftUI

@MainActor
struct SettingsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Section {
            Toggle("Notifications", isOn: Binding(
                get: { model.notificationsEnabled },
                set: { enabled in Task { await model.setNotificationsEnabled(enabled) } }
            ))

            Stepper(value: $model.emergencyUnlockDelay, in: 0...600, step: 15) {
                LabeledContent("Emergency unlock wait", value: "\(model.emergencyUnlockDelay)s")
            }

            NavigationLink { ShieldTextView() } label: {
                Label("Block screen text", systemImage: "text.bubble")
            }
            NavigationLink { AppIconPickerView() } label: {
                Label("App icon", systemImage: "app.badge")
            }
            NavigationLink { DiagnosticsView() } label: {
                Label("Signing diagnostics", systemImage: "stethoscope")
            }

            if let expiry = ProvisioningProfile.embedded?.expirationDate {
                LabeledContent("Refresh in SideStore by") {
                    Text(expiry, style: .date)
                }
            }
        } header: {
            Text("Settings")
        } footer: {
            Text("With notifications on, you get a reminder a day before this copy's signature expires.")
        }
    }
}
