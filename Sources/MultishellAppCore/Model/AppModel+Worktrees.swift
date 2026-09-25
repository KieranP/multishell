import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The worktree whose terminals are on screen: the selected one unless the
  /// board covers them. Everything acting on the tab in front asks here.
  var worktreeInView: Worktree? {
    showsAgentBoard ? nil : workspace.selectedWorktree
  }

  /// The worktree in view when a shell may start in it. `nil` otherwise,
  /// the missing-directory alert already raised.
  func worktreeReadyForShell() -> Worktree? {
    worktreeInView.flatMap { readyForShell($0) ? $0 : nil }
  }

  /// Whether a shell may start in `worktree`: no create or remove running or
  /// failed there, and its directory present. Every way of starting one asks.
  func readyForShell(_ worktree: Worktree) -> Bool {
    !isBusy(worktree.id) && requireDirectory(of: worktree)
  }

  /// A worktree with no tabs gets one unless `TabOpening` says otherwise, and
  /// this is where the shared-hooks question is asked, a create being asked apart.
  @discardableResult
  public func select(_ worktree: Worktree, openingFirstTab: TabOpening = .onSelect) -> Bool {
    // A row git no longer lists is refused by the store, so ask first: the
    // board closing and a tab opening are not things to do for nothing.
    guard workspace.worktree(worktree.id) != nil, requireDirectory(of: worktree) else {
      return false
    }
    // Before anything else, `isShown` having to agree that panes fill the
    // detail area. The seen-clearing is left to the reconcile at the end.
    hideAgentBoard(markingFocusedPaneSeen: false)
    store.selectWorktree(worktree.id)
    warmWorktrees.insert(worktree.id)
    if openingFirstTab != .onCreate { askAboutSharedSettingsIfNeeded(for: worktree.projectID) }
    if !isBusy(worktree.id), workspace.tabs(in: worktree.id).isEmpty,
      opensTab(in: worktree, on: openingFirstTab)
    {
      openFirstOrNewTab(in: worktree, on: openingFirstTab)
    }
    reconcileSessions(takingFocus: true)
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
  public func beginRenamingWorktree(_ worktree: Worktree) {
    guard workspace.worktree(worktree.id) != nil else { return }
    if let project = workspace.project(worktree.projectID), !project.isExpanded {
      setExpanded(true, for: project)
    }
    renamingWorktreeID = worktree.id
  }

  /// The field's Return, or the focus leaving it. Ignored once the rename has
  /// ended, so an Escape is not undone by the commit losing focus triggers.
  public func commitWorktreeRename(of id: Worktree.ID, to name: String) {
    guard renamingWorktreeID == id else { return }
    renamingWorktreeID = nil
    store.setCustomName(name, forWorktree: id)
  }

  /// The field's Escape: the name stays as it was.
  public func cancelRenamingWorktree() {
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

  /// The checkout, the file lists or the post-create hook are still
  /// filling it, so git reads a half-made tree; see worktrees.md.
  func isUnderConstruction(_ id: Worktree.ID) -> Bool {
    workInFlight.isClaimed(id) || worktreeOperations.isUnderWay(id)
      || workspace.worktree(id)?.isInitializing == true
  }

  /// The same for a worktree in hand, which the poll asks of every row: the
  /// lookup by id scans the list, and a round asking it per row went quadratic.
  func isUnderConstruction(_ worktree: Worktree) -> Bool {
    workInFlight.isClaimed(worktree.id) || worktreeOperations.isUnderWay(worktree.id)
      || worktree.isInitializing
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
    workInFlight.stopStage(of: worktree.id)
  }

  public func setHookTimeoutSeconds(_ seconds: Int) {
    store.setHookTimeoutSeconds(seconds)
  }

  public func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    store.setWorktreeDefaults(defaults)
  }

  /// Checked before anything that starts a shell, a missing directory being
  /// refused. Named for the demand, since it raises the alert itself.
  func requireDirectory(of worktree: Worktree) -> Bool {
    switch directoryProbe.probe(worktree.path.path) {
    case .present: return true
    case .missing: presentedError = .worktreeDirectoryMissing(worktree.path.path)
    case .unanswered: presentedError = .worktreeDirectoryUnanswered(worktree.path.path)
    }
    return false
  }

  /// The one place per-worktree runtime state is dropped, fed with what the
  /// store discarded. Paths are ids, so a worktree re-made there starts clean.
  func forgetWorktrees(_ ids: [Worktree.ID]) {
    guard !ids.isEmpty else { return }
    let gone = Set(ids)
    setIfChanged(\.statuses, statuses.filter { !gone.contains($0.key) })
    setIfChanged(\.mergeStates, mergeStates.filter { !gone.contains($0.key) })
    setIfChanged(\.lastCommits, lastCommits.filter { !gone.contains($0.key) })
    mergeChecks = mergeChecks.filter { !gone.contains($0.key) }
    mergeReads.forget(gone)
    resolvedWorktreePaths = resolvedWorktreePaths.filter { !gone.contains($0.key) }
    // Their sessions went with them, so a worktree re-made at the path starts cold.
    warmWorktrees.subtract(gone)
    statusReads.forget(gone)
    worktrees?.forgetStatusReads(of: ids)
    for id in ids {
      // A stage still running has no pane left to Cancel from, so it is ended
      // as that Cancel would end it; its task lets go of these as it returns.
      workInFlight.stopStage(of: id)
      worktreeOperations.clear(id)
      pendingStatusRefreshes[id]?.cancel()
      pendingStatusRefreshes[id] = nil
    }
    if let renaming = renamingWorktreeID, gone.contains(renaming) { renamingWorktreeID = nil }
    if let pending = pendingWorktreeRemoval, gone.contains(pending.worktree.id) {
      pendingWorktreeRemoval = nil
    }
    if let latest = latestRemovalRequest, gone.contains(latest) { latestRemovalRequest = nil }
  }

  /// The deepest worktree holding the directory. A hook's `cwd` may be the
  /// resolved path of one added through a symlink, so both spellings are tried.
  func worktree(atPath path: String) -> Worktree? {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    let spellings = [url.standardizedFileURL, url.resolvingSymlinksInPath()].map(\.pathComponents)
    // Depth is the matching root's, not the written path's: a symlink chain
    // can spell a shallow worktree long.
    let matches = workspace.worktrees.compactMap { worktree -> (Worktree, Int)? in
      let depth = [worktree.path.pathComponents, resolvedComponents(of: worktree)]
        .filter { root in spellings.contains { $0.starts(with: root) } }
        .map(\.count).max()
      return depth.map { (worktree, $0) }
    }
    return matches.max { $0.1 < $1.1 }?.0
  }

  /// Kept per worktree: each report naming only a directory walked every
  /// worktree's symlinks, on the main actor, a network mount's among them.
  private func resolvedComponents(of worktree: Worktree) -> [String] {
    if let known = resolvedWorktreePaths[worktree.id] { return known }
    let resolved = worktree.path.resolvingSymlinksInPath().pathComponents
    resolvedWorktreePaths[worktree.id] = resolved
    return resolved
  }
}
