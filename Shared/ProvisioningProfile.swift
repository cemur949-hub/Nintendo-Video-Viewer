import Foundation

/// Entitlement keys this project cares about.
enum EntitlementKey {
    static let familyControls = "com.apple.developer.family-controls"
    static let nfcReaderFormats = "com.apple.developer.nfc.readersession.formats"
    static let appGroups = "com.apple.security.application-groups"
    static let teamIdentifier = "com.apple.developer.team-identifier"
}

/// The provisioning profile that SideStore (or Xcode) embedded when it signed a bundle.
///
/// The profile lists what Apple allowed for this App ID. A capability that isn't
/// in the profile can't be in the signed binary either, because iOS won't launch
/// a binary that claims more than its profile allows.
struct ProvisioningProfile {
    let name: String?
    let teamIdentifiers: [String]
    let creationDate: Date?
    let expirationDate: Date?
    let entitlements: [String: Any]

    var appGroups: [String] { entitlements[EntitlementKey.appGroups] as? [String] ?? [] }

    /// Profiles for free Apple IDs last 7 days. Paid-program development profiles last a year.
    var looksLikeFreeAccount: Bool? {
        guard let creationDate, let expirationDate else { return nil }
        return expirationDate.timeIntervalSince(creationDate) <= 8 * 24 * 60 * 60
    }

    /// The profile embedded in the running bundle (app or extension), if any.
    static let embedded: ProvisioningProfile? = load(from: .main)

    static func load(from bundle: Bundle) -> ProvisioningProfile? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision") else { return nil }
        return load(contentsOf: url)
    }

    /// `.mobileprovision` is a CMS (PKCS #7) envelope with a plain XML plist inside,
    /// so we cut out the plist instead of verifying the signature.
    static func load(contentsOf url: URL) -> ProvisioningProfile? {
        guard let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil
              ) as? [String: Any]
        else { return nil }

        return ProvisioningProfile(
            name: plist["Name"] as? String,
            teamIdentifiers: plist["TeamIdentifier"] as? [String] ?? [],
            creationDate: plist["CreationDate"] as? Date,
            expirationDate: plist["ExpirationDate"] as? Date,
            entitlements: plist["Entitlements"] as? [String: Any] ?? [:]
        )
    }
}
