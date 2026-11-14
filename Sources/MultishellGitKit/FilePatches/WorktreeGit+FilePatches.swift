import Foundation
import MultishellCore

/// One file's changes against `HEAD` or the Branch list's merge base, for its
/// tab; see Docs/design/files/file-tabs.md.
extension WorktreeGit {
  /// Every line in context: large enough for any file under the size cap. git
  /// takes larger values, but 4294967296 wraps to no context at all.
  private static let wholeFileContext = 2_147_483_647

  /// The fixed prefixes and `suppressBlankEmpty` keep a user's config out of the
  /// parser, and the algorithm is the badge's, so the tab counts alike.
  static func patchArguments(_ algorithm: DiffAlgorithm) -> [String] {
    [
      "-c", "diff.suppressBlankEmpty=false",
      "--no-optional-locks", "--literal-pathspecs", "diff-index", "-p", "--no-ext-diff",
      "--no-textconv", "--no-color", "--no-renames", "--diff-algorithm=\(algorithm.rawValue)",
      "--src-prefix=a/", "--dst-prefix=b/", "--unified=\(wholeFileContext)",
    ]
  }

  /// Against `commit`, else `knownBase` or `HEAD` or the empty tree; `diff-index`
  /// writes nothing to the index, see worktrees/watching-and-status-reads.md.
  public func patches(
    of path: String,
    in directory: URL,
    diffAlgorithm: DiffAlgorithm,
    since commit: String? = nil,
    knownBase: String? = nil,
  ) async -> FilePatches? {
    let arguments = Self.patchArguments(diffAlgorithm)
    if let commit {
      guard let onDisk = await runner.outputBytes(arguments + [commit, "--", path], in: directory)
      else { return nil }
      return FilePatches(onDisk: onDisk, staged: nil)
    }
    let base: String?
    if let knownBase { base = knownBase } else { base = await diffBase(in: directory) }
    guard let base else { return nil }
    // Two runs at once: neither reads what the other writes.
    async let onDiskRun = runner.outputBytes(arguments + [base, "--", path], in: directory)
    async let stagedRun = runner.outputBytes(
      arguments + ["--cached", base, "--", path],
      in: directory,
    )
    guard let onDisk = await onDiskRun, let staged = await stagedRun else { return nil }
    return FilePatches(onDisk: onDisk, staged: staged)
  }

  /// `HEAD`, or the empty tree's id where `HEAD` is unborn; `nil` where git
  /// could answer neither.
  public func diffBase(in directory: URL) async -> String? {
    if await hasCommits(in: directory) {
      return "HEAD"
    }
    return await emptyTreeID(in: directory)
  }
}
