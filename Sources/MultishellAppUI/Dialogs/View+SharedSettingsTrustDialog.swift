import MultishellAppCore
import SwiftUI

extension View {
  /// The one-time question about what a repository's `.multishell.json`
  /// asks to run or read, asked when the user turns to that project.
  func sharedSettingsTrustDialog(model: AppModel) -> some View {
    questionDialog(
      model.pendingSharedSettingsTrust,
      title: \.title,
      message: \.message,
      dismiss: { _ in model.decideSharedSettingsTrustLater() },
      buttons: { pending in
        Button(pending.trustLabel) { model.answerSharedSettingsTrust(pending, isTrusted: true) }
        Button(pending.declineLabel) { model.answerSharedSettingsTrust(pending, isTrusted: false) }
          .keyboardShortcut(.defaultAction)
        Button(t("dialog.decide-later"), role: .cancel) { model.decideSharedSettingsTrustLater() }
      },
    )
  }
}
