import AppKit
import MultishellAppCore
import SwiftUI

extension View {
  /// Asked before Abort Merge or Abort Rebase throws away what an agent working in
  /// the worktree may have resolved.
  func updateAbortAlert(model: AppModel) -> some View {
    destructiveAlert(model.pendingUpdateAbort) { pending in
      DestructiveAlert.make(
        title: pending.title,
        message: pending.message,
        choices: [pending.confirmLabel],
      )
    } answer: { pending, choice in
      model.answerUpdateAbort(pending, confirmed: choice != nil)
    }
  }
}
