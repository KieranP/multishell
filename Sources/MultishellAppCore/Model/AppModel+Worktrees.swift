import Foundation
import MultishellCore
import MultishellGitKit

// MARK: - The worktree in view, its name, and the operation running on it

extension AppModel {
  /// A worktree with no tabs gets one unless `TabOpening` says otherwise, and
  /// this is where the shared-hooks question is asked.
  @discardableResult
  public func select(
    _ worktree: Worktree, openingFirstTab: TabOpening = .onSelect, byUser: Bool = true
  )
    -> Bool
  {
    guard requireDirectory(of: worktree) else { return false }
    // Before anything else, `isShown` having to agree that panes fill the
    // detail area. The seen-clearing is left to the `sync` at the end.
    leaveAgentBoard()
    store.selectWorktree(worktree.id)
    warmWorktrees.insert(worktree.id)
    if byUser { askAboutSharedHooksIfNeeded(for: worktree.projectID) }
    if !isBusy(worktree.id), workspace.tabs(in: worktree.id).isEmpty,
      opensTab(in: worktree, on: openingFirstTab)
    {
      openFirstOrNewTab(in: worktree, on: openingFirstTab)
    }
    sync()
    return true
  }

  /// The name the user gave this worktree, or `nil` for none.
  public func customName(of worktree: Worktree) -> String? {
    workspace.customName(of: worktree.id)
  }

  /// What a row or a header calls this worktree: the user's name where they
  /// gave one, else its branch.
  public func displayName(of worktree: Worktree) -> String {
    workspace.displayName(of: worktree)
  }

  /// The menus' Rename: the row swaps its name for a field. The project is
  /// opened first, a collapsed one leaving no row to type into.
  public func beginRenaming(_ worktree: Worktree) {
    guard workspace.worktree(worktree.id) != nil else { return }
    store.setExpanded(true, forProject: worktree.projectID)
    renamingWorktreeID = worktree.id
  }

  /// The field's Return, or the focus leaving it. Ignored once the rename has
  /// ended, so an Escape is not undone by the commit losing focus triggers.
  public func commitRename(of id: Worktree.ID, to name: String) {
    guard renamingWorktreeID == id else { return }
    renamingWorktreeID = nil
    store.setCustomName(name, forWorktree: id)
  }

  /// The field's Escape: the name stays as it was.
  public func cancelRenaming() {
    renamingWorktreeID = nil
  }

  /// Sets or clears a name without going through the field; `nil` is the
  /// menu's Use Branch Name.
  public func renameWorktree(_ id: Worktree.ID, to name: String?) {
    renamingWorktreeID = nil
    store.setCustomName(name, forWorktree: id)
  }

  /// A create or remove is running there, or has failed and not been
  /// dismissed. Nothing starts a shell until then.
  public func isBusy(_ id: Worktree.ID) -> Bool {
    worktreeOperations.isBusy(id)
  }

  /// The pane's Dismiss after a failed stage. A dismissed create stage
  /// hands over the way a finished one does: the first tab opens.
  public func dismissOperationFailure(of worktree: Worktree) {
    guard let operation = worktreeOperations.dismiss(worktree.id) else { return }
    if operation.step.isCreation { openHeldBackTab(of: worktree) }
  }

  /// The pane's Cancel: ends the stage running there, a hook by signal and a
  /// file list at its next path. What follows depends on the stage.
  public func cancelStage(of worktree: Worktree) {
    stageStoppers[worktree.id]?.stop()
  }

  public func setHookTimeoutSeconds(_ seconds: Int) {
    store.setHookTimeoutSeconds(seconds)
  }

  /// Checked before anything that starts a shell, a missing directory being
  /// refused. Named for the demand, since it raises the alert itself.
  public func requireDirectory(of worktree: Worktree) -> Bool {
    if FileManager.default.fileExists(atPath: worktree.path.path) { return true }
    presentedError = .worktreeDirectoryMissing(worktree.path.path)
    return false
  }
}
