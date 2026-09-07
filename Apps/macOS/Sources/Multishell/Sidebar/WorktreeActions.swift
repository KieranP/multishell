import MultishellCore
import SwiftUI

/// The items that act on one worktree, shared by the detail header's menu,
/// the sidebar's context menu and any other place a worktree is shown, so a
/// new action appears in all of them at once.
struct WorktreeActions: View {
  let model: AppModel
  let worktree: Worktree

  var body: some View {
    // The field it opens is on the sidebar row, wherever the menu was
    // asked for; the model carries which worktree is being renamed.
    Button("Rename…") { model.beginRenaming(worktree) }
    if model.customName(of: worktree) != nil {
      Button("Use Branch Name") { model.renameWorktree(worktree.id, to: nil) }
    }
    Divider()
    Button("Open in Editor") { model.openInEditor(worktree) }
    Button("Reveal in Finder") { model.revealInFileBrowser(worktree.path) }
    Button("Copy Path") { model.copyToClipboard(worktree.path.path) }
    Button("Copy Branch") { model.copyToClipboard(worktree.name) }
    Divider()
    // Selected first, so the menu opens the tab where it was asked for
    // whichever worktree the detail view is showing, and without the first
    // tab a select would add. Always a shell: the agent has its own item,
    // so auto-start does not apply here.
    Button("New Shell Tab") {
      if model.select(worktree, openingFirstTab: .never) { model.newShellTab() }
    }
    .disabled(model.isBusy(worktree.id))
    if model.preferredAgentID(for: worktree) != nil {
      Button("New Agent Tab") {
        if model.select(worktree, openingFirstTab: .never) { model.newAgentTab() }
      }
      .disabled(model.isBusy(worktree.id))
    }
    if model.state(ofWorktree: worktree.id) != nil {
      Divider()
      Button("Clear Status") { model.clearState(ofWorktree: worktree.id) }
    }
    if !worktree.isPrimary {
      Divider()
      Button("Remove Worktree…", role: .destructive) { model.requestRemoval(of: worktree) }
        .disabled(model.isBusy(worktree.id))
    }
  }
}
