import FamilyControls
import SwiftUI

@MainActor
struct BlockListSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingPicker = false

    var body: some View {
        // Attach the picker only when Family Controls is usable, so FamilyControls UI
        // never loads in a copy whose entitlement was stripped.
        if model.report.canBlockApps {
            section.familyActivityPicker(
                isPresented: $showingPicker,
                selection: Binding(get: { model.selection }, set: { model.updateSelection($0) })
            )
        } else {
            section
        }
    }

    private var section: some View {
        Section {
            Button {
                showingPicker = true
            } label: {
                Label("Choose apps & websites", systemImage: "square.grid.2x2")
            }
            .disabled(!model.report.canBlockApps || model.isEffectivelyLocked)

            Text(model.selectionSummary).foregroundColor(.secondary)
        } header: {
            Text("Blocked while locked")
        } footer: {
            if model.report[.familyControls] == .stripped {
                Text("Unavailable in this copy: the Family Controls entitlement was stripped at signing.")
            } else if model.isEffectivelyLocked {
                Text("You can't change the block list while locked.")
            }
        }
    }
}
