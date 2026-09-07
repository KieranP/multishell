import Foundation
import MultishellCore
import MultishellGitKit

// MARK: - The worktree in view, its name, and the operation running on it

extension AppModel {
  /// A worktree with no tabs gets one, unless the setting for why it is
  /// being shown says to leave the first shell to Cmd+T or the actions
  /// menu; see `TabOpening`. Returns false when the directory is gone and
  /// nothing was selected, so that caller does not act on whatever was
  /// selected.
  ///
  /// Selecting is where the question about the repository's shared hooks is
  /// asked; `byUser: false` is for the selection that follows a create,
  /// which lands while the sheet is still going away and would lose the
  /// dialog under it.
  @discardableResult
  public func select(
    _ worktree: Worktree, openingFirstTab: TabOpening = .onSelect, byUser: Bool = true
  )
    -> Bool
  {
    guard directoryExists(of: worktree) else { return false }
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

  /// The menus' Rename: the sidebar row swaps its name for a field. The
  /// project is opened first, since the item is also in the detail header's
  /// menu, where a collapsed project would leave no row to type into.
  /// Nothing for a worktree that has gone since the menu opened.
  public func beginRenaming(_ worktree: Worktree) {
    guard workspace.worktree(worktree.id) != nil else { return }
    store.setExpanded(true, forProject: worktree.projectID)
    renamingWorktreeID = worktree.id
  }

  /// The field's Return, or the focus leaving it. Ignored once the rename
  /// has ended, so the Escape that cancels is not undone by the commit that
  /// losing focus would otherwise trigger.
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

  /// A create or remove is running on the worktree, or has failed and not
  /// been dismissed. Nothing starts a shell there until then: a post-create
  /// hook is still installing, the worktree is about to go, or the pane is
  /// saying what went wrong.
  public func isBusy(_ id: Worktree.ID) -> Bool {
    worktreeOperations.isBusy(id)
  }

  /// The pane's Dismiss after a failed stage. A dismissed post-create
  /// failure hands over the way a finished hook does: the first tab opens.
  public func dismissOperationFailure(of worktree: Worktree) {
    guard let operation = worktreeOperations.dismiss(worktree.id) else { return }
    if operation.step == .postCreateHook { openHeldBackTab(of: worktree) }
  }

  /// The pane's Stop Hook: ends the hook running on the worktree, which
  /// then reports itself stopped. What follows depends on the stage; see
  /// `runPostCreateHook` and `removeWorktree`.
  public func stopHook(of worktree: Worktree) {
    hookStoppers[worktree.id]?.stop()
  }

  public func setHookTimeoutSeconds(_ seconds: Int) {
    store.setHookTimeoutSeconds(seconds)
  }

  /// Checked before anything that starts a shell: selecting, a new tab, a
  /// split. A missing directory is refused, not worked around.
  public func directoryExists(of worktree: Worktree) -> Bool {
    if FileManager.default.fileExists(atPath: worktree.path.path) { return true }
    presentedError = .worktreeDirectoryMissing(worktree.path.path)
    return false
  }
}
