import MultishellCore

extension AppModel {
  /// The play button's menu, the quick switcher or an action's keys: runs it
  /// in its own tab here, asking first where something still runs in that tab.
  public func runAction(named name: String, in worktree: Worktree) {
    runAction(named: name, in: worktree, bringsIntoView: true)
  }

  /// `bringsIntoView` false is the command line's, which starts the run in the
  /// background as `tabs open` does, leaving the user's view and keyboard alone.
  func runAction(named name: String, in worktree: Worktree, bringsIntoView: Bool) {
    // As a new tab is: no action starts where a create or remove runs.
    guard isShellReadyBesidesDirectory(worktree),
      let action = actionsInForce(for: worktree).first(where: { $0.name == name })
    else { return }
    if let session = actionSession(named: name, in: worktree.id) {
      guard !isOccupied(actionSession: session.id) else {
        pendingActionRestart = PendingActionRestart(
          worktreeID: worktree.id,
          sessionID: session.id,
          actionName: name,
        )
        return
      }
      rerun(action, replacing: session.id, in: worktree, bringsIntoView: bringsIntoView)
      return
    }
    launch(in: worktree, bringsIntoView: bringsIntoView) {
      guard
        let tab = store.openTab(in: worktree.id, title: action.name, actionName: action.name)
      else { return }
      pendingActionRuns[tab.focusedSessionID] = action
    }
  }

  /// A menu bar action item, or its keys: the action in the selected worktree.
  public func runActionInSelectedWorktree(named name: String) {
    guard let worktree = workspace.selectedWorktree else { return }
    runAction(named: name, in: worktree)
  }

  /// Restart stops the run in its tab and starts the action there again.
  public func answerActionRestart(_ pending: PendingActionRestart, restarts: Bool) {
    answerActionRestart(pending, restarts: restarts, asked: true)
  }

  /// `asked` false is the command line's `--restart`, which no dialog put up
  /// and which restarts in the background.
  func answerActionRestart(_ pending: PendingActionRestart, restarts: Bool, asked: Bool) {
    if asked {
      // A rename since asks again, under a new id, so the first sheet's answer is dropped.
      guard pendingActionRestart?.id == pending.id else { return }
      pendingActionRestart = nil
    }
    // By the tab's name now, not the question's: the action may have been
    // renamed in Settings while the question stood.
    guard restarts, let worktree = workspace.worktree(pending.worktreeID),
      let name = workspace.session(pending.sessionID)?.actionName,
      let action = actionsInForce(for: worktree).first(where: { $0.name == name })
    else { return }
    rerun(action, replacing: pending.sessionID, in: worktree, bringsIntoView: asked)
  }

  /// A restart question names its action as it is now after a rename, and goes
  /// once its tab's action is gone or out of force, Restart having nothing to restart.
  func settlePendingActionRestart() {
    guard let pending = pendingActionRestart else { return }
    guard let session = workspace.session(pending.sessionID),
      let name = session.actionName,
      let worktree = workspace.worktree(session.worktreeID),
      actionsInForce(for: worktree).contains(where: { $0.name == name })
    else {
      pendingActionRestart = nil
      return
    }
    guard name != pending.actionName else { return }
    pendingActionRestart = PendingActionRestart(
      worktreeID: pending.worktreeID,
      sessionID: pending.sessionID,
      actionName: name,
    )
  }

  /// What was kept about a tab goes with it: a restart question has nothing
  /// left to ask. Run from the reconcile, as `prunePendingClose` is.
  func pruneActions() {
    let sessions = Set(workspace.sessions.map(\.id))
    setIfChanged(\.actionRunStarts, actionRunStarts.filter { sessions.contains($0.key) })
    pendingActionRuns = pendingActionRuns.filter { sessions.contains($0.key) }
    guard let pending = pendingActionRestart, !sessions.contains(pending.sessionID) else { return }
    pendingActionRestart = nil
  }

  /// A fresh session in the old one's pane: the engine ends the old shell as
  /// it does a closed tab's, and the new one starts the action.
  private func rerun(
    _ action: ProjectAction,
    replacing id: TerminalSession.ID,
    in worktree: Worktree,
    bringsIntoView: Bool,
  ) {
    guard isShellReadyBesidesDirectory(worktree) else { return }
    launch(in: worktree, bringsIntoView: bringsIntoView) {
      guard let session = store.replaceSession(id) else { return }
      pendingActionRuns[session.id] = action
    }
  }

  /// `change` opens or replaces the run's session; the reconcile after it
  /// starts the shell, taking the keyboard only where the worktree is shown.
  private func launch(in worktree: Worktree, bringsIntoView: Bool, _ change: () -> Void) {
    guard !bringsIntoView else {
      select(worktree, openingFirstTab: .never, turning: change)
      return
    }
    change()
    warmWorktrees.insert(worktree.id)
    reconcileSessions(takingFocus: isInView(worktree))
  }
}
