import SwiftUI
import UIKit

/// Shows what SideStore actually signed: bundle ID, team, profile expiry,
/// entitlements, App Group and extensions.
@MainActor
struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var copied = false

    var body: some View {
        let diagnostics = DiagnosticsReport.make(report: model.report)
        List {
            Section("Capabilities") {
                ForEach(CapabilityKind.allCases) { kind in
                    CapabilityRow(kind: kind, status: model.report[kind])
                }
            }
            ForEach(diagnostics.blocks) { block in
                Section(block.title) {
                    ForEach(block.items) { item in
                        LabeledContent(item.label) {
                            Text(item.value).multilineTextAlignment(.trailing).textSelection(.enabled)
                        }
                    }
                }
            }
            Section {
                Button(copied ? "Copied" : "Copy diagnostics") {
                    UIPasteboard.general.string = diagnostics.text
                    copied = true
                }
            }
        }
        .navigationTitle("Diagnostics")
        .refreshable { await model.refresh() }
    }
}
