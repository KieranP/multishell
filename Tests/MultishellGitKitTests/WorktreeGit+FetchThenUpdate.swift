import MultishellCore

@testable import MultishellGitKit

extension WorktreeGit {
  /// The fetch, then the merge or rebase, as the app runs them with its checks between.
  func fetchThenUpdate(
    _ worktree: Worktree,
    from base: DefaultBranch,
    by method: UpdateMethod,
  ) async throws -> BaseUpdateOutcome {
    try await fetch(base, into: worktree)
    return try await update(worktree, from: base, by: method)
  }
}
