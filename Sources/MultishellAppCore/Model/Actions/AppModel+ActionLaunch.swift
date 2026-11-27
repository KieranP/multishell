import MultishellCore

extension AppModel {
  /// The line `session` runs `action` with: prepared for launch, so it
  /// carries the port, and its shell takes the tab once the action ends.
  func actionCommand(_ action: ProjectAction, for session: TerminalSession) -> [String] {
    let values = worktreeAndProject(session.worktreeID).map(placeholderValues) ?? [:]
    return ActionLaunch.command(
      for: action,
      values: values,
      in: session.workingDirectory,
      hasPort: session.port != nil,
      tabShell: session.shellPath,
    )
  }
}
