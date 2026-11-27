import Foundation

/// How `multishell worktrees update` ended, as it prints it.
struct WorktreeUpdateReceipt: Encodable, Equatable {
  enum Outcome: String, Encodable {
    case updated
    case conflicts
  }

  let outcome: Outcome
  /// The paths git left unmerged; empty once updated.
  let conflicts: [String]
  /// The pane opened on them where the project sends conflicts to its agent.
  let pane: UUID?
}
