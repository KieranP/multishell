import Foundation
import MultishellCore
import MultishellGitKit

extension CommittedSide {
  /// The merge base with `base` for the worktree's own file, else `HEAD`, taken from
  /// `bases` where a read resolved them; `nil` where git cannot say which.
  static func resolved(
    of repository: RepositoryLocation,
    in worktree: URL,
    since base: DefaultBranch?,
    isGone: Bool,
    git: WorktreeGit,
    bases: WorktreeDiffBases? = nil,
  ) async -> Self? {
    var commit: String?
    let ownBases = repository.directory == worktree ? bases : nil
    if base != nil, let ownBases {
      commit = ownBases.branchCommit
    } else if let base, repository.directory == worktree {
      do {
        commit = try await git.branchCommit(since: base, in: worktree)
      } catch {
        return nil
      }
    }
    // A size git could not read is no answer, not a file the merge base lacks.
    let size: Int?
    if let known = ownBases?.committedSize(of: repository.path) {
      size = known
    } else {
      do {
        size = try await git.committedSize(
          of: repository.path,
          in: repository.directory,
          at: commit,
        )
      } catch {
        return nil
      }
    }
    guard commit != nil, size == nil, isGone else {
      return Self(
        commit: commit,
        size: size,
        marksStaging: commit == nil,
        bases: ownBases,
      )
    }
    // Added by the branch and deleted, `HEAD`'s copy is shown removed, staging unmarked;
    // none there either is the missing notice, and only a throw leaves git unable to say.
    let headSize: Int?
    do {
      headSize = try await git.committedSize(of: repository.path, in: repository.directory)
    } catch {
      return nil
    }
    return Self(
      commit: nil,
      size: headSize,
      marksStaging: false,
      bases: ownBases,
    )
  }
}
