import MultishellAppCore
import MultishellCore
import SwiftUI

/// What the repository asks for is used only once trusted, and a change
/// asks again; the grey text in the hook editors is what it is.
struct SharedSettingsTrustSection: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let isTrusted = model.trustsSharedSettings(of: project)
    Section {
      HStack(spacing: 8) {
        Text(isTrusted ? t("hooks.shared-run") : t("hooks.shared-ignored"))
        Spacer()
        Button(isTrusted ? t("hooks.stop-trusting") : t("hooks.trust")) {
          model.setTrustsSharedSettings(!isTrusted, for: project)
        }
        .controlSize(.small)
      }
    } header: {
      InfoLabel(
        sectionHeader: t("hooks.shared-header", SharedProjectSettings.fileName),
        info: t("hooks.shared-info", SharedProjectSettings.fileName))
    }
  }
}
