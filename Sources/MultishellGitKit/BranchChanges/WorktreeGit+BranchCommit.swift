import Foundation
import MultishellCore

extension WorktreeGit {
  /// What a Branch diff counts from: the merge base, else `nil` where that is
  /// `HEAD` or none is shared, `HEAD` serving; a throw where git cannot say.
  public func branchCommit(since base: DefaultBranch, in worktree: URL) async throws -> String? {
    async let mergeBase = mergeBase(with: base, inRepositoryAt: worktree)
    async let head = headCommit(in: worktree)
    guard let found = try await mergeBase else { return nil }
    return found == (await head) ? nil : found
  }
}
