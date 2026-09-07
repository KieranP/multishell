import MultishellAppCore
import SwiftUI

extension View {
  /// The confirmation that removing a worktree asks for, when the settings
  /// have not already settled both the removal and its branch.
  func worktreeRemovalDialog(model: AppModel) -> some View {
    confirmationDialog(
      model.pendingRemoval?.title ?? "",
      isPresented: Binding(
        get: { model.pendingRemoval != nil }, set: { if !$0 { model.pendingRemoval = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingRemoval
    ) { pending in
      // The order is the value's: a merged branch leads with the button
      // that deletes it. See `PendingWorktreeRemoval.choices`.
      ForEach(pending.choices, id: \.label) { choice in
        Button(choice.label, role: .destructive) {
          model.pendingRemoval = nil
          Task {
            await model.removeWorktree(pending.worktree, deletingBranch: choice.deletesBranch)
          }
        }
      }
      Button("Cancel", role: .cancel) { model.pendingRemoval = nil }
    } message: { pending in
      Text(pending.message(warning: model.removalWarning(for: pending.worktree)))
    }
  }
}
