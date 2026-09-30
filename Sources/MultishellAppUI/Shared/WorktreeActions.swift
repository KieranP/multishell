import MultishellAppCore
import MultishellCore
import SwiftUI

/// The items that act on one worktree, shared by every menu that shows one,
/// so a new action appears in all of them at once.
struct WorktreeActions: View {
  let model: AppModel
  let worktree: Worktree

  var body: some View {
    // The field it opens is on the sidebar row, wherever the menu was
    // asked for; the model carries which worktree is being renamed.
    Button(t("action.rename")) { model.beginRenamingWorktree(worktree) }
    if model.customName(of: worktree) != nil {
      Button(t("action.use-branch-name")) { model.renameWorktree(worktree.id, to: nil) }
    }
    Divider()
    Button(t("action.open-in-editor")) { model.openInEditor(worktree) }
    Button(t("action.reveal-in-finder")) { model.revealInFileBrowser(worktree.path) }
    Button(t("action.copy-path")) { model.copyToClipboard(worktree.path.path) }
    Button(t("action.copy-branch")) { model.copyToClipboard(worktree.name) }
    Divider()
    // Always a shell: the agent has its own item, so auto-start does not apply.
    Button(t("menu.new-shell-tab")) { model.newShellTab(selecting: worktree) }
      .disabled(model.isBusy(worktree.id))
    if model.effectiveAgentID(for: worktree) != nil {
      Button(t("menu.new-agent-tab")) { model.newAgentTab(selecting: worktree) }
        .disabled(model.isBusy(worktree.id))
    }
    if model.state(ofWorktree: worktree.id) != nil {
      Divider()
      Button(t("action.clear-status")) { model.clearState(ofWorktree: worktree.id) }
    }
    if worktree.isRemovable {
      Divider()
      Button(t("action.remove-worktree"), role: .destructive) {
        model.requestWorktreeRemoval(of: worktree)
      }
      .disabled(model.isBusy(worktree.id))
    }
  }
}
