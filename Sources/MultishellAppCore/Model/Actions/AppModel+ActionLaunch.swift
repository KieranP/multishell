import MultishellCore

extension AppModel {
  /// The line `session` runs the action with: prepared for launch, so it
  /// carries the port, and its shell takes the tab once the action ends.
  func actionCommand(_ run: PendingActionRun, for session: TerminalSession) -> [String] {
    let pickedRow = workspace.worktrees.first { row in
      row.id == session.worktreeID && row.projectID == run.projectID
    }
    let row = pickedRow ?? workspace.worktree(session.worktreeID)
    let values =
      row.flatMap { row in effectiveProject(of: row).map { placeholderValues((row, $0)) } } ?? [:]
    return ActionLaunch.command(
      for: run.action,
      values: values,
      in: session.workingDirectory,
      hasPort: session.port != nil,
      tabShell: session.shellPath,
    )
  }
}
