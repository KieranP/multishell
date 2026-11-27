import MultishellCore

/// Where Send Conflicts To can go: the worktree's agent panes, and a new tab
/// where the project has an agent to start in one.
public struct ConflictSendTargets: Equatable, Sendable {
  public let recipients: [HandoffRecipient]
  public let opensAgentTab: Bool
}
