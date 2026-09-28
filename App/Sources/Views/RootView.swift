import SwiftUI

@MainActor
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                if !model.report.issues.isEmpty {
                    CapabilityIssuesSection()
                }
                LockSection()
                BlockListSection()
                TagsSection()
                ScheduleSection()
                SettingsSection()
            }
            .navigationTitle(Bundle.main.displayName)
        }
        .task { await model.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .alert(
            model.alert?.title ?? "",
            isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
            presenting: model.alert,
            actions: { _ in Button("OK", role: .cancel) {} },
            message: { alert in Text(alert.message) }
        )
    }
}
