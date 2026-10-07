import AppKit
import MultishellAppCore
import SwiftUI

extension View {
  /// Asked before a close ends a pane or tab whose agent last reported that
  /// it is still working, whichever key, button or menu asked for it.
  func pendingCloseAlert(model: AppModel) -> some View {
    destructiveAlert(model.pendingClose) { pending in
      DestructiveAlert.make(
        title: pending.title,
        message: t("dialog.agent-still-working"),
        choices: [pending.buttonLabel])
    } answer: { pending, choice in
      model.answerClose(pending, confirmed: choice != nil)
    }
  }
}
