import SwiftUI

/// Edits the text the ShieldConfiguration extension shows on blocked apps.
@MainActor
struct ShieldTextView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $model.shieldText.title)
                TextField("Message", text: $model.shieldText.message, axis: .vertical)
                    .lineLimit(2...5)
                Button("Restore defaults") { model.shieldText = .default }
            } footer: {
                Text(footer)
            }
        }
        .navigationTitle("Block screen text")
    }

    private var footer: String {
        if model.report[.appGroup] != .ready || model.report[.extensions] != .ready {
            return "The custom block screen needs the Shield Configuration extension and an App Group. This copy is missing one of them, so iOS shows its default block screen."
        }
        return "Shown when you open a blocked app or website."
    }
}
