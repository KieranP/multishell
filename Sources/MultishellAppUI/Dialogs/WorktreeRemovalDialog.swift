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
        message: pending.message(warning: model.worktreeRemovalWarning(for: pending.worktree)),
        choices: pending.choices.map(\.label),
        cancel: t("action.cancel"))
    } answer: { pending, choice in
      model.pendingWorktreeRemoval = nil
      guard let choice, pending.choices.indices.contains(choice) else { return }
      let deletesBranch = pending.choices[choice].deletesBranch
      Task { await model.confirmWorktreeRemoval(pending, deletingBranch: deletesBranch) }
    }
  }
}
