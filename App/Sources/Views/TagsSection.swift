import SwiftUI

@MainActor
struct TagsSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var isNaming = false
    @State private var newTagName = ""

    var body: some View {
        Section {
            ForEach(model.tags) { tag in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.name)
                    Text("Added \(tag.addedAt, style: .date)").font(.caption).foregroundColor(.secondary)
                }
            }
            .onDelete { model.removeTags(at: $0) }
            .deleteDisabled(model.isEffectivelyLocked)

            Button {
                isNaming = true
            } label: {
                Label("Register a tag", systemImage: "wave.3.right")
            }
            .disabled(!model.canScanTags)
        } header: {
            Text("NFC keys")
        } footer: {
            Text(footer)
        }
        .alert("Name this tag", isPresented: $isNaming) {
            TextField("e.g. Desk tag", text: $newTagName)
            Button("Scan") {
                let name = newTagName
                newTagName = ""
                Task { await model.registerTag(named: name) }
            }
            Button("Cancel", role: .cancel) { newTagName = "" }
        }
    }

    private var footer: String {
        switch model.report[.nfc] {
        case .stripped:
            return "NFC Tag Reading was stripped when this copy was signed, so tags can't be registered."
        case .unsupported(let reason):
            return reason
        default:
            return "Any NFC sticker, card or key fob works, blank or not. The app only stores a hash of the tag's ID."
        }
    }
}
