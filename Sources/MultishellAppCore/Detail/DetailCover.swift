/// What fills the detail area in place of the selected worktree's terminals,
/// whose shells stay live under it.
enum DetailCover: Sendable, Equatable {
  case agentBoard
  case debugInfo
}
