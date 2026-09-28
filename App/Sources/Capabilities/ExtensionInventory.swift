import Foundation

/// Checks which app extensions made it into the installed bundle.
/// SideStore can remove extensions at install time to save App IDs.
enum ExtensionInventory {
    struct Expected {
        let pointIdentifier: String
        let purpose: String
    }

    static let expected = [
        Expected(pointIdentifier: "com.apple.deviceactivity.monitor-extension", purpose: "Scheduled locks"),
        Expected(pointIdentifier: "com.apple.ManagedSettingsUI.shield-configuration-service", purpose: "Custom block screen"),
    ]

    /// Extension point identifier → bundle file name, for every .appex in PlugIns.
    static func installed() -> [String: String] {
        guard let directory = Bundle.main.builtInPlugInsURL,
              let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [:] }

        var result: [String: String] = [:]
        for url in urls where url.pathExtension == "appex" {
            guard let info = Bundle(url: url)?.object(forInfoDictionaryKey: "NSExtension") as? [String: Any],
                  let point = info["NSExtensionPointIdentifier"] as? String
            else { continue }
            result[point] = url.lastPathComponent
        }
        return result
    }

    static func missing() -> [Expected] {
        let installed = installed()
        return expected.filter { installed[$0.pointIdentifier] == nil }
    }
}
