import MultishellGitKit

/// What the Files panel counts its changes against, which its footer says.
enum ChangeComparison: Equatable, Sendable {
  case branch(BranchChanges)
  /// The Files list, or Modified: the status read's changes since `HEAD`.
  case head
  /// Branch, in a project with no base branch to compare with.
  case noBase
  /// Branch, before its first read lands.
  case unread
  /// Branch, its last read failed with none before it to keep.
  case unreadable(baseName: String)

  /// What the tree marks under Branch, `nil` for the status read's own.
  var branchChanges: [StatusChange]? {
    switch self {
    case .branch(let changes): changes.changes
    case .head: nil
    case .noBase, .unread, .unreadable: []
    }
  }
}
