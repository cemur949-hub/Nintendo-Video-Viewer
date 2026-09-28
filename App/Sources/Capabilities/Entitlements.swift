import Foundation

enum EntitlementState: Equatable {
    case present
    /// Asked for in the project but missing from this signed copy.
    case missing
    /// Neither the code signature nor a provisioning profile could be read (e.g. Simulator).
    case unknown

    var label: String {
        switch self {
        case .present: return "Present"
        case .missing: return "Missing (stripped at signing)"
        case .unknown: return "Unknown"
        }
    }
}

/// What this signed copy of the app is actually entitled to.
///
/// The code signature is the source of truth. The embedded provisioning profile
/// is the fallback: anything missing from the profile can't be in the binary.
enum Entitlements {
    static let signed: [String: Any]? = CodeSignature.entitlements(ofExecutableAt: Bundle.main.executableURL)

    enum Source: String {
        case codeSignature = "Code signature"
        case provisioningProfile = "Provisioning profile"
        case none = "Not available"
    }

    static var source: Source {
        if signed != nil { return .codeSignature }
        if ProvisioningProfile.embedded != nil { return .provisioningProfile }
        return .none
    }

    static var familyControls: EntitlementState {
        state(of: EntitlementKey.familyControls) { ($0 as? Bool) == true }
    }

    /// Reading tag UIDs with NFCTagReaderSession needs the "TAG" format.
    static var nfcTagReading: EntitlementState {
        state(of: EntitlementKey.nfcReaderFormats) { ($0 as? [String])?.contains("TAG") == true }
    }

    static var appGroups: EntitlementState {
        state(of: EntitlementKey.appGroups) { !(($0 as? [String]) ?? []).isEmpty }
    }

    static func value(for key: String) -> Any? {
        (signed ?? ProvisioningProfile.embedded?.entitlements)?[key]
    }

    private static func state(of key: String, isGranted: (Any) -> Bool) -> EntitlementState {
        guard let entitlements = signed ?? ProvisioningProfile.embedded?.entitlements else { return .unknown }
        guard let value = entitlements[key] else { return .missing }
        return isGranted(value) ? .present : .missing
    }
}
