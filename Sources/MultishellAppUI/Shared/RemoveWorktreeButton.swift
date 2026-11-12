import MultishellAppCore
import MultishellCore
import SwiftUI

/// Remove Worktree, greyed while Remove may not start: the menus' item and
/// the merged pull request page's button.
struct RemoveWorktreeButton: View {
  let model: AppModel
  let worktree: Worktree

  var body: some View {
    Button(t("action.remove-worktree"), role: .destructive) {
      model.requestWorktreeRemoval(of: worktree)
    }
    .disabled(!model.mayRemove(worktree))
  }
}
