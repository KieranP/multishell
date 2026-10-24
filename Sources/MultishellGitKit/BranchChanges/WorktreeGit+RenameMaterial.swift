import Foundation
import MultishellCore
import MultishellProcess

/// Auto Rename's read of a branch: commits and the index against the merge
/// base, so unstaged and untracked work is left out. See Docs/design/agents.md.
extension WorktreeGit {
  private static let renameSubjectLimit = 50
  /// About 5,000 tokens of diff, a small fraction of any listed model's window.
  static let renameDiffByteLimit = 20_000
  private static let renameDiffstatFileLimit = 60

  /// The whole lines that fit in `limit` bytes, so no character is split.
  private static func cutAtLine(_ bytes: Data, limit: Int) -> Data {
    guard bytes.count > limit else { return bytes }
    let head = bytes.prefix(limit)
    guard let lastBreak = head.lastIndex(of: UInt8(ascii: "\n")) else { return Data() }
    return Data(head[...lastBreak])
  }

  /// The stat before the patch's first file header, and the patch from it. The
  /// header opens a line, so a path spelling it in the stat is not taken for it.
  private static func split(_ output: Data) -> (stat: Data, patch: Data) {
    let header = Data("\ndiff --git ".utf8)
    guard let found = output.range(of: header) else { return (output, Data()) }
    let patchStart = found.lowerBound + 1
    return (Data(output[..<patchStart]), Data(output[patchStart...]))
  }

  /// `nil` where the branch shares no history with the base, which leaves
  /// nothing to compare. Throws where git cannot say.
  public func renameMaterial(
    inRepositoryAt path: URL,
    since base: DefaultBranch,
  ) async throws -> RenameMaterial? {
    try await renameMaterial(
      inRepositoryAt: path,
      since: base,
      diffByteLimit: Self.renameDiffByteLimit,
    )
  }

  func renameMaterial(
    inRepositoryAt path: URL,
    since base: DefaultBranch,
    diffByteLimit: Int,
  ) async throws -> RenameMaterial? {
    guard let start = try await renameStart(inRepositoryAt: path, since: base) else { return nil }
    // A merge's subject says what was merged in, not what the branch does.
    async let log =
      start.hasCommits
      ? runner.run(
        [
          "log", "--no-merges", "--format=%s", "--max-count=\(Self.renameSubjectLimit)",
          "\(start.commit)..HEAD", "--",
        ],
        in: path,
      ) : ""
    // One diff for the stat and the patch, which git would otherwise compute twice.
    // `--no-ext-diff` and `--no-textconv`: a repository's diff drivers run programs.
    async let diff = runner.runBytes(
      [
        "--no-optional-locks", "diff", "--cached", "--no-color", "--no-ext-diff",
        "--no-textconv", "--stat=100", "--stat-count=\(Self.renameDiffstatFileLimit)",
        "--patch", start.commit, "--",
      ],
      in: path,
    )
    async let branch = runner.output(["symbolic-ref", "--short", "-q", "HEAD"], in: path)
    let (subjects, output, branchName) = try await (log, diff, branch)
    let (stat, patch) = Self.split(output)
    let cut = Self.cutAtLine(patch, limit: diffByteLimit)
    return RenameMaterial(
      branch: branchName.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
      subjects: subjects.split(separator: "\n").map(String.init),
      diffstat: String(decoding: stat, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines),
      // A NUL would end the prompt's argument there, argv being C strings.
      diff: String(decoding: cut.filter { $0 != 0 }, as: UTF8.self),
      isDiffCut: cut.count < patch.count,
    )
  }

  /// The merge base, or the empty tree for a branch with no commit yet, so its
  /// staged files still name it. `nil` where it shares no history with the base.
  private func renameStart(
    inRepositoryAt path: URL,
    since base: DefaultBranch,
  ) async throws -> (commit: String, hasCommits: Bool)? {
    if let mergeBase = try await mergeBase(with: base, inRepositoryAt: path) {
      return (mergeBase, true)
    }
    guard await headCommit(in: path) == nil, let empty = await emptyTreeID(in: path) else {
      return nil
    }
    return (empty, false)
  }
}
