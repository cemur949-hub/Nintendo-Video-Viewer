import UIKit

/// App icons bundled in Assets.xcassets. The alternates are listed in
/// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES (Config/App.xcconfig), so
/// they ship inside the app. Nothing is downloaded.
enum AppIcon: String, CaseIterable, Identifiable {
    case standard, midnight, sunrise, mono

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    /// Name passed to `setAlternateIconName`. nil means the primary icon.
    var alternateIconName: String? {
        self == .standard ? nil : "AppIcon-\(rawValue.capitalized)"
    }

    /// Image set used to preview the icon in the picker. Icon sets can't be loaded with `Image(_:)`.
    var previewImageName: String { "IconPreview-\(rawValue.capitalized)" }

    @MainActor
    static var current: AppIcon {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateIconName == name } ?? .standard
    }
}
