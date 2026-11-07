import Foundation
import MultishellCore
import MultishellGitKit

extension CommittedSide {
  /// The merge base with `base` for the worktree's own file, else `HEAD`; `nil`
  /// where git cannot say which.
  static func resolved(
    of repository: RepositoryLocation,
    in worktree: URL,
    since base: DefaultBranch?,
    isGone: Bool,
    git: WorktreeGit,
  ) async -> Self? {
    var commit: String?
    if let base, repository.directory == worktree {
      async let mergeBase = git.mergeBase(with: base, inRepositoryAt: worktree)
      async let head = git.headCommit(in: worktree)
      // No shared history is an answer, `HEAD`; only a throw leaves git unable to say.
      do {
        commit = try await mergeBase
      } catch {
        return nil
      }
      // On the base itself the index holds nothing past `HEAD`, so its marks stay exact.
      if let found = commit, found == (await head) { commit = nil }
    }
    // A size git could not read is no answer, not a file the merge base lacks.
    let size: Int?
    do {
      size = try await git.committedSize(of: repository.path, in: repository.directory, at: commit)
    } catch {
      return nil
    }
    guard commit != nil, size == nil, isGone else {
      return Self(commit: commit, size: size, marksStaging: commit == nil)
    }
    // Added by the branch and deleted, `HEAD`'s copy is shown removed, staging unmarked;
    // none there either is the missing notice, and only a throw leaves git unable to say.
    let headSize: Int?
    do {
      headSize = try await git.committedSize(of: repository.path, in: repository.directory)
    } catch {
      return nil
    }
    return Self(commit: nil, size: headSize, marksStaging: false)
  }
}
