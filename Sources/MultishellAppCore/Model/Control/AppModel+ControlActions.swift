import MultishellCore

extension AppModel {
  private static func word(for state: ActionRunState) -> String {
    switch state {
    case .idle: "idle"
    case .running: "running"
    case .done: "done"
    case .failed: "failed"
    }
  }

  func replyToListActions(of id: String) -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    let menu = actionMenu(for: worktree)
    return .json(
      ActionListing(
        worktree: id,
        actions: (menu?.items ?? []).map { item in
          ActionListing.Action(
            name: item.name,
            state: Self.word(for: item.state),
            keys: item.keys?.spelled,
          )
        },
        awaitingTrust: menu?.awaitingTrust ?? [],
      )
    )
  }

  /// The play menu's pick, never its restart question: a run still going is
  /// refused unless `restart` says to stop it.
  func replyToRunAction(_ id: String, name: String, restart: Bool, force: Bool) -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    let menu = actionMenu(for: worktree)
    guard menu?.items.contains(where: { $0.name == name }) == true else {
      let isAwaitingTrust = menu?.awaitingTrust.contains(name) == true
      return .refused(isAwaitingTrust ? .actionNotTrusted(name: name) : .actionNotFound(name: name))
    }
    guard requireShellReady(worktree) else { return .refused(.worktreeNotReady(id: id)) }
    if let session = actionSession(named: name, in: worktree.id),
      isOccupied(actionSession: session.id)
    {
      guard restart else { return .refused(.actionTabOccupied(name: name)) }
      if refusesOverWorkingAgent(in: [session.id], force: force) { return .refused(.agentWorking) }
      answerActionRestart(
        PendingActionRestart(worktreeID: worktree.id, sessionID: session.id, actionName: name),
        restarts: true,
        asked: false,
      )
      return .done
    }
    runAction(named: name, in: worktree, bringsIntoView: false)
    return .done
  }
}
