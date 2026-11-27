import MultishellAppCore
import MultishellCore
import SwiftUI

/// What the repository asks for is used only once trusted, and a change
/// asks again; the page below shows what it asks for.
struct SharedSettingsTrustSection: View {
  let model: AppModel
  let project: Project
  let lines: SharedSettingsTrustLines

  var body: some View {
    let isTrusted = model.trustsSharedSettings(of: project)
    SettingsGroup {
      HStack(spacing: 8) {
        Text(isTrusted ? lines.trusted : lines.untrusted)
        Spacer()
        Button(isTrusted ? t("shared-settings.stop-trusting") : t("shared-settings.trust")) {
          model.setTrustsSharedSettings(!isTrusted, for: project)
        }
      }
    } header: {
      InfoLabel(
        sectionHeader: t("shared-settings.header", SharedProjectSettings.fileName),
        info: lines.info,
      )
    }
  }
}
