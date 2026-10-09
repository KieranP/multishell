import MultishellCore

/// One pane row under the worktree in view, as the row draws it.
public struct SidebarPane: Identifiable, Equatable, Sendable {
  public let id: TerminalSession.ID
  public let title: String
  public let position: PanePosition?
  public let isFocused: Bool
  public let state: SessionState?
  public let workers: [Worker]
  public let agentID: String?
  let agentName: String?
}
