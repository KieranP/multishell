import MultishellAppCore
import SwiftUI

extension View {
  /// Merge from Base or Rebase onto Base's question, where an agent works there
  /// or a rebase rewrites pushed commits.
  func baseUpdateDialog(model: AppModel) -> some View {
    questionDialog(
      model.pendingBaseUpdate,
      title: \.title,
      message: \.message,
      dismiss: { model.answerBaseUpdate($0, confirmed: false) },
      buttons: { pending in
        Button(pending.confirmLabel) { model.answerBaseUpdate(pending, confirmed: true) }
          .keyboardShortcut(.defaultAction)
        Button(t("action.cancel"), role: .cancel) {
          model.answerBaseUpdate(pending, confirmed: false)
        }
      },
    )
  }
}
