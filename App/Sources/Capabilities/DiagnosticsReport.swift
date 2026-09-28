import Foundation

/// Plain-text signing and capability details for the Diagnostics screen and bug reports.
struct DiagnosticsReport {
    struct Item: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    struct Block: Identifiable {
        let title: String
        let items: [Item]
        var id: String { title }
    }

    let blocks: [Block]

    var text: String {
        blocks.map { block in
            (["## \(block.title)"] + block.items.map { "\($0.label): \($0.value)" }).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    static func make(report: CapabilityReport) -> DiagnosticsReport {
        let info = Bundle.main.infoDictionary ?? [:]
        let profile = ProvisioningProfile.embedded
        let installed = ExtensionInventory.installed()

        let accountType: String
        switch profile?.looksLikeFreeAccount {
        case true?: accountType = "Free Apple ID (7-day profile)"
        case false?: accountType = "Paid developer account"
        case nil: accountType = "Unknown"
        }

        let signing = Block(title: "Signing", items: [
            Item(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "–"),
            Item(label: "Original bundle ID", value: info["ALTBundleIdentifier"] as? String ?? "Not re-signed by SideStore"),
            Item(label: "Version", value: "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"),
            Item(label: "Team ID", value: Entitlements.value(for: EntitlementKey.teamIdentifier) as? String
                ?? profile?.teamIdentifiers.first ?? "–"),
            Item(label: "Profile", value: profile?.name ?? "None embedded"),
            Item(label: "Profile expires", value: profile?.expirationDate.map(formatExpiry) ?? "–"),
            Item(label: "Account type", value: accountType),
            Item(label: "Entitlements read from", value: Entitlements.source.rawValue),
        ])

        let entitlements = Block(title: "Entitlements", items: [
            Item(label: "Family Controls", value: Entitlements.familyControls.label),
            Item(label: "NFC Tag Reading", value: Entitlements.nfcTagReading.label),
            Item(label: "App Groups", value: Entitlements.appGroups.label),
        ])

        let appGroup = Block(title: "App Group", items: [
            Item(label: "Requested", value: AppGroup.requestedIdentifier ?? "–"),
            Item(label: "In use", value: AppGroup.identifier ?? "None (settings stay local)"),
            Item(label: "Candidates", value: AppGroup.candidates().joined(separator: ", ")),
        ])

        let extensions = Block(title: "Extensions", items: ExtensionInventory.expected.map {
            Item(label: $0.purpose, value: installed[$0.pointIdentifier] ?? "Missing")
        })

        let capabilities = Block(title: "Capabilities", items: CapabilityKind.allCases.map {
            Item(label: $0.title, value: report[$0].label)
        })

        return DiagnosticsReport(blocks: [signing, entitlements, appGroup, extensions, capabilities])
    }

    private static func formatExpiry(_ date: Date) -> String {
        let absolute = date.formatted(date: .abbreviated, time: .shortened)
        let relative = RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        return "\(absolute) (\(relative))"
    }
}
