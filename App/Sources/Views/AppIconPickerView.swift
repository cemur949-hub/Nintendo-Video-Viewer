import SwiftUI

@MainActor
struct AppIconPickerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                ForEach(AppIcon.allCases) { icon in
                    Button {
                        model.setIcon(icon)
                    } label: {
                        HStack(spacing: 16) {
                            Image(icon.previewImageName)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
                            Text(icon.title).foregroundColor(.primary)
                            Spacer()
                            if model.currentIcon == icon {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            } footer: {
                Text("All icons ship inside the app. Nothing is downloaded.")
            }
        }
        .navigationTitle("App icon")
    }
}
