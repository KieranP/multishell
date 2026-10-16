import Foundation
import MultishellCore
import MultishellProcess

/// One file's changes against `HEAD`, for its tab; see Docs/design/files.md.
extension WorktreeGit {
  /// Every line in context: large enough for any file under the size cap. git
  /// takes larger values, but 4294967296 wraps to no context at all.
  private static let wholeFileContext = 2_147_483_647

  /// The fixed prefixes and `suppressBlankEmpty` keep a user's config out of the
  /// parser, and the algorithm is the badge's, so the tab counts alike.
  private static func patchArguments(_ algorithm: DiffAlgorithm) -> [String] {
    [
      "-c", "diff.suppressBlankEmpty=false",
      "--no-optional-locks", "--literal-pathspecs", "diff-index", "-p", "--no-ext-diff",
      "--no-textconv", "--no-color", "--no-renames", "--diff-algorithm=\(algorithm.rawValue)",
      "--src-prefix=a/", "--dst-prefix=b/", "--unified=\(wholeFileContext)",
    ]
  }

  /// `diff-index` writes nothing to the index. Before the first commit both
  /// sides diff against the empty tree, and only then; see worktrees.md.
  public func patches(
    of path: String,
    in directory: URL,
    diffAlgorithm: DiffAlgorithm,
  ) async -> FilePatches? {
    guard let base = await diffBase(in: directory) else { return nil }
    let arguments = Self.patchArguments(diffAlgorithm)
    guard
      let onDisk = await runner.outputBytes(arguments + [base, "--", path], in: directory),
      let staged = await runner.outputBytes(
        arguments + ["--cached", base, "--", path],
        in: directory,
      )
    else { return nil }
    return FilePatches(onDisk: onDisk, staged: staged)
  }

  /// `HEAD`, or the empty tree's id where `HEAD` is unborn; `nil` where git
  /// could answer neither.
  private func diffBase(in directory: URL) async -> String? {
    if await hasCommits(in: directory) {
      return "HEAD"
    }
    return await emptyTreeID(in: directory)
  }
}
