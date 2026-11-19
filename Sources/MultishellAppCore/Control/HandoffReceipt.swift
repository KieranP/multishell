import Foundation

/// What `multishell pr send` and `ci send` print: how many items went to which
/// agent pane.
struct HandoffReceipt: Encodable, Equatable {
  /// Its worktree's `ControlID`.
  let worktree: String
  let pane: UUID
  let agent: String
  let itemCount: Int
}
