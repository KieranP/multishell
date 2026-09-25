import MultishellCore

/// What the New Worktree sheet asks of a project's repository, read in one
/// go each time its picker lands on a project.
public struct NewWorktreeBranches: Equatable, Sendable {
  let hasCommits: Bool
  let localBranches: [String]
  let remoteBranches: [String]
  let currentBranch: String
}
