import AppKit
import MultishellAppCore
import SwiftUI

extension View {
  /// Asked before a close ends a pane or tab whose agent last reported that it
  /// is still working, or a review comment being written; whatever asked for it.
  func pendingCloseAlert(model: AppModel) -> some View {
    destructiveAlert(model.pendingClose) { pending in
      DestructiveAlert.make(
        title: pending.title,
        message: pending.message,
        choices: [pending.buttonLabel],
      )
    } answer: { pending, choice in
      model.answerClose(pending, confirmed: choice != nil)
    }
  }
}
