import SwiftUI

/// Shown at the top of the main screen when a capability is missing or needs permission.
@MainActor
struct CapabilityIssuesSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Section {
            ForEach(model.report.issues) { kind in
                CapabilityRow(kind: kind, status: model.report[kind])
            }
            NavigationLink { DiagnosticsView() } label: {
                Label("Signing diagnostics", systemImage: "stethoscope")
            }
        } header: {
            Text("Needs attention")
        }
    }
}

@MainActor
struct CapabilityRow: View {
    @EnvironmentObject private var model: AppModel
    let kind: CapabilityKind
    let status: CapabilityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: status.symbol).foregroundColor(status.tint)
                Text(kind.title).font(.headline)
                Spacer()
                Text(status.label).font(.caption).foregroundColor(.secondary)
            }
            Text(kind.message(for: status))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            action
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var action: some View {
        switch (kind, status) {
        case (.familyControls, .needsPermission):
            Button("Allow Screen Time access") { Task { await model.requestScreenTimeAccess() } }
                .buttonStyle(.borderedProminent)
        case (.notifications, .needsPermission):
            Button("Allow notifications") { Task { await model.setNotificationsEnabled(true) } }
                .buttonStyle(.bordered)
        case (_, .denied):
            Button("Open Settings") { model.openSettings() }
                .buttonStyle(.bordered)
        default:
            EmptyView()
        }
    }
}
