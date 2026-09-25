import MultishellCore

/// The paths a create is checking out into, before git lists them. Asked by
/// every read that must leave a half-made tree alone.
struct WorktreePathClaims: Sendable {
  /// Counted, not a set: two creates can name one path; see worktrees.md.
  private var claims: [Worktree.ID: Int] = [:]

  init() {}

  /// A path is being checked out into. The caller has already found no
  /// worktree listed there; see `AppModel.claimConstruction`.
  mutating func claim(_ id: Worktree.ID) {
    claims[id, default: 0] += 1
  }

  /// One claim let go, not the path: another create may still hold it.
  mutating func release(_ id: Worktree.ID) {
    guard let count = claims[id], count > 1 else {
      claims[id] = nil
      return
    }
    claims[id] = count - 1
  }

  func isClaimed(_ id: Worktree.ID) -> Bool { claims[id] != nil }
}
