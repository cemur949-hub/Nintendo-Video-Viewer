import Foundation
import os

/// Finds the App Group identifier at runtime.
///
/// Don't hard-code the group ID. SideStore/AltStore register App Groups under
/// the signing team and append the Team ID, so `group.com.example.app` becomes
/// `group.com.example.app.ABCDE12345`. They record the final IDs in every
/// bundle's Info.plist under `ALTAppGroups`. Resolution order:
///
/// 1. `ALTAppGroups`: written by SideStore when it re-signs.
/// 2. The embedded provisioning profile: what the signer was granted.
/// 3. `AppGroupIdentifier`: what we asked for at build time (Xcode-signed builds).
///
/// Candidates that start with our requested ID come first. The first one iOS
/// gives us a container for wins.
enum AppGroup {
    static let requestedIdentifierKey = "AppGroupIdentifier"
    static let sideStoreGroupsKey = "ALTAppGroups"

    /// The group requested at build time (`APP_GROUP_ID` in Config/Identity.xcconfig).
    static var requestedIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: requestedIdentifierKey) as? String
    }

    /// The group this signed copy can actually use, or nil if App Groups were stripped.
    static let identifier: String? = {
        let resolved = candidates().first {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
        }
        if let resolved {
            Log.signing.info("App Group resolved to \(resolved, privacy: .public)")
        } else {
            Log.signing.error("No usable App Group; shared settings fall back to local storage")
        }
        return resolved
    }()

    static var isAvailable: Bool { identifier != nil }

    /// Every group ID we know about, most likely first.
    static func candidates() -> [String] {
        var found: [String] = []
        for bundle in [Bundle.main, hostAppBundle].compactMap({ $0 }) {
            found += bundle.object(forInfoDictionaryKey: sideStoreGroupsKey) as? [String] ?? []
            found += ProvisioningProfile.load(from: bundle)?.appGroups ?? []
        }
        if let requested = requestedIdentifier { found.append(requested) }

        var seen = Set<String>()
        let unique = found.filter { seen.insert($0).inserted }
        guard let requested = requestedIdentifier else { return unique }
        return unique.filter { $0.hasPrefix(requested) } + unique.filter { !$0.hasPrefix(requested) }
    }

    /// Inside an app extension, the containing `.app` bundle (…/App.app/PlugIns/X.appex).
    private static var hostAppBundle: Bundle? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "appex" else { return nil }
        return Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent())
    }
}
