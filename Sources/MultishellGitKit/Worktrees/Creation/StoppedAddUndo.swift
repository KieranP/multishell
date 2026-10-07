import Foundation

/// What a stopped `git worktree add` made that nothing else had.
struct StoppedAddUndo: Sendable {
  let path: URL
  let worktreeIsNew: Bool
  let newBranch: String?
  let highestMissingAncestor: URL?
}
