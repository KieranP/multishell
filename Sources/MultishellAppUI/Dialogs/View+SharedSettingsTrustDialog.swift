import MultishellAppCore
import SwiftUI

extension View {
  /// The one-time question about what a repository's `.multishell.json`
  /// asks to run or read, asked when the user turns to that project.
  func sharedSettingsTrustDialog(model: AppModel) -> some View {
    confirmationDialog(
      model.pendingSharedSettingsTrust?.title ?? "",
      isPresented: Binding(
        get: { model.pendingSharedSettingsTrust != nil },
        set: { if !$0 { model.decideSharedSettingsTrustLater() } },
      ),
      titleVisibility: .visible,
      presenting: model.pendingSharedSettingsTrust,
    ) { pending in
      Button(pending.trustLabel) { model.answerSharedSettingsTrust(pending, isTrusted: true) }
      Button(pending.declineLabel) { model.answerSharedSettingsTrust(pending, isTrusted: false) }
        .keyboardShortcut(.defaultAction)
      Button(t("dialog.decide-later"), role: .cancel) { model.decideSharedSettingsTrustLater() }
    } message: { pending in
      Text(pending.message)
    }
  }
}
