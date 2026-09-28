import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customises the screen iOS shows when you open a blocked app or website.
/// The title and message come from the App Group; defaults are used without it.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(blockedName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(blockedName: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(blockedName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(blockedName: webDomain.domain ?? category.localizedDisplayName)
    }

    private func makeConfiguration(blockedName: String?) -> ShieldConfiguration {
        let text = SharedStore.shared.shieldText
        let title = blockedName.map { "\(text.title): \($0)" } ?? text.title

        return ShieldConfiguration(
            backgroundBlurStyle: .systemChromeMaterialDark,
            backgroundColor: UIColor(red: 0.13, green: 0.11, blue: 0.33, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: text.message, color: UIColor.white.withAlphaComponent(0.8)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white),
            primaryButtonBackgroundColor: .systemIndigo
        )
    }
}
