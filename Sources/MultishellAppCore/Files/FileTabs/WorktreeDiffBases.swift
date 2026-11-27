import Foundation
import MultishellCore
import MultishellGitKit

/// What every file of one read counts from, asked of git once a read: asked a file
/// at a time, the All changes tab cost several git runs a file.
struct WorktreeDiffBases: Sendable {
  /// The merge base with the Branch list's base; `nil` under Modified, or on
  /// the base itself, where `HEAD` serves.
  let branchCommit: String?
  /// `HEAD`, or the empty tree's id where `HEAD` is unborn.
  let headOrEmptyTree: String
  /// The read's files' sizes on the committed side; one absent has none there.
  private let committedSizes: [String: Int]
  private let ignored: Set<String>
  private let indexed: Set<String>
  /// Diffed up front, many files a run, against `branchCommit`.
  private let patches: [String: FilePatches]
  /// The paths the sizes and ignores were asked for; any other asks git itself.
  private let paths: Set<String>

  /// `nil` where git cannot say, each file then asking for itself.
  /// `diffable` names the paths worth diffing up front: text under the cap.
  static func resolve(
    in worktree: URL,
    since base: DefaultBranch?,
    paths: [String],
    diffable: Set<String>,
    diffAlgorithm: DiffAlgorithm,
    git: WorktreeGit,
  ) async -> Self? {
    async let diffBase = git.diffBase(in: worktree)
    var branchCommit: String?
    if let base {
      do {
        branchCommit = try await git.branchCommit(since: base, in: worktree)
      } catch {
        return nil
      }
    }
    guard let headOrEmptyTree = await diffBase else { return nil }
    async let sizes = git.committedSizes(
      of: paths,
      in: worktree,
      at: branchCommit ?? headOrEmptyTree,
    )
    async let ignored = git.ignoredPaths(paths, in: worktree)
    async let indexed = git.indexedPaths(paths, in: worktree)
    guard let sizes = await sizes, let ignored = await ignored, let indexed = await indexed
    else { return nil }
    // An untracked file is read with no diff, and one past the cap never diffs.
    let toDiff = paths.filter { path in
      diffable.contains(path) && indexed.contains(path)
        && (sizes[path] ?? 0) <= FileTabReader.sizeLimit
    }
    let patches = await git.patches(
      ofMany: toDiff,
      in: worktree,
      diffAlgorithm: diffAlgorithm,
      since: branchCommit,
      base: headOrEmptyTree,
    )
    return Self(
      branchCommit: branchCommit,
      headOrEmptyTree: headOrEmptyTree,
      committedSizes: sizes,
      ignored: ignored,
      indexed: indexed,
      patches: patches ?? [:],
      paths: Set(paths),
    )
  }

  /// The committed size of a path the read asked about, `.some(nil)` where
  /// the committed side lacks it; `nil` for a path it did not ask about.
  func committedSize(of path: String) -> Int?? {
    paths.contains(path) ? .some(committedSizes[path]) : nil
  }

  /// A path's patches diffed up front where they were against `commit`;
  /// `nil` for any other, read alone.
  func patches(of path: String, since commit: String?) -> FilePatches? {
    commit == branchCommit ? patches[path] : nil
  }

  /// Whether the index lacks a path the read asked about; `nil` for any other.
  func isUntracked(_ path: String) -> Bool? {
    paths.contains(path) ? !indexed.contains(path) : nil
  }

  /// Whether git ignores a path the read asked about; `nil` for any other.
  func isIgnored(_ path: String) -> Bool? {
    paths.contains(path) ? ignored.contains(path) : nil
  }
}
