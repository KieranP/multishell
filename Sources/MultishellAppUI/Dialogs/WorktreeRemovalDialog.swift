import MultishellAppCore
import SwiftUI

extension View {
  /// The confirmation that removing a worktree asks for, when the settings
  /// have not already settled both the removal and its branch.
  func worktreeRemovalDialog(model: AppModel) -> some View {
    destructiveAlert(model.pendingWorktreeRemoval) { pending in
      // The order is the value's: a merged branch leads with the button
      // that deletes it. See `PendingWorktreeRemoval.choices`.
      DestructiveAlert.make(
        title: pending.title,
        message: pending.message(warning: model.worktreeRemovalWarning(for: pending)),
        choices: pending.choices.map(\.label))
    } answer: { pending, choice in
      model.answerWorktreeRemoval(pending, choice: choice)
    }
  }
}
