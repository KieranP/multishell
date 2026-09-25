import MultishellCore

/// One `git status` answer and what it cost, so a slow checkout can be
/// asked less often.
public struct StatusReading: Sendable {
  public let status: WorktreeStatus
  public let took: Duration
}
