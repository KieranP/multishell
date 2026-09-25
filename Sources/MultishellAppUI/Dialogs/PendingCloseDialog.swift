import AppKit
import MultishellAppCore
import SwiftUI

extension View {
  /// Asked when Cmd+W would close a pane or tab whose agent last reported
  /// that it is still working.
  func pendingCloseDialog(model: AppModel) -> some View {
    destructiveAlert(model.pendingClose) { pending in
      DestructiveAlert.make(
        title: pending.title,
        message: t("dialog.agent-still-working"),
        choices: [pending.buttonLabel],
        cancel: t("action.cancel"))
    } answer: { _, choice in
      // `confirmPendingClose` reads the pending close and clears it itself.
      if choice == nil { model.pendingClose = nil } else { model.confirmPendingClose() }
    }
  }
}
