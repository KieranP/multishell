import Foundation
import MultishellCore

/// What a worktree holds against its branch, for the sidebar's badges.
extension WorktreeGit {
  /// `--diff-filter=u` drops unmerged paths, which print `0 0`. Renames and the
  /// algorithm are set here so a user's own git config cannot move the counts.
  private static func numstatOptions(_ algorithm: DiffAlgorithm) -> [String] {
    ["--numstat", "--diff-filter=u", "--no-renames", "--diff-algorithm=\(algorithm.rawValue)"]
  }

  /// `--no-optional-locks`: a plain `git status` takes `index.lock`, failing a
  /// `git commit` typed at that moment. See worktrees.md for `countsEveryNewFile`.
  func status(
    of worktree: Worktree,
    counting indicator: GitStatusIndicator = .default,
    diffAlgorithm: DiffAlgorithm = .default,
    countsEveryNewFile: Bool = false,
  )
    async throws -> WorktreeStatus
  {
    let output = try await runner.run(
      ["--no-optional-locks", "status", "--porcelain=v1", "--branch", "--no-renames"],
      in: worktree.path,
    )
    var status = WorktreeStatusParser.parse(output)
    guard status.isDirty else { return status }
    let counts = await lineCounts(
      in: worktree.path,
      counting: indicator,
      diffAlgorithm: diffAlgorithm,
      untrackedCount: status.untracked,
    )
    status.insertions = counts.insertions
    status.deletions = counts.deletions
    status.unscoredFiles = counts.unscoredFiles
    if countsEveryNewFile, status.untracked > 0,
      let count = await changedFileCountListingEveryNewFile(in: worktree.path)
    {
      status.changedFiles = count
    }
    return status
  }

  /// Only on a read someone asked for: walking every new folder cost 294 ms on a
  /// large tree where the badge's read takes 115 ms; see worktrees.md.
  private func changedFileCountListingEveryNewFile(in path: URL) async -> Int? {
    let entries = await runner.output(
      [
        "--no-optional-locks", "status", "--porcelain=v1", "-z", "--untracked-files=all",
        "--no-renames",
      ],
      in: path,
    )
    return entries?.split(separator: "\0").count
  }

  /// `--cached` is the index alone, and the fallback wherever the count
  /// since the last commit fails; see worktrees.md.
  private func lineCounts(
    in path: URL,
    counting indicator: GitStatusIndicator,
    diffAlgorithm: DiffAlgorithm,
    untrackedCount: Int,
  ) async -> LineCounts {
    let options = Self.numstatOptions(diffAlgorithm)
    let cachedOnly = ["--no-optional-locks", "diff"] + options + ["--cached"]
    var counts = LineCounts()
    if indicator == .stagedAndUnstaged,
      let output = await numstatSinceLastCommit(in: path, options: options)
    {
      counts = NumstatParser.parse(output)
    } else if let cached = await runner.output(cachedOnly, in: path) {
      counts = NumstatParser.parse(cached)
    }
    guard indicator == .stagedAndUnstaged, untrackedCount > 0 else { return counts }
    let untrackedLines = await untrackedCounts(in: path)
    counts.insertions += untrackedLines.insertions
    counts.unscoredFiles += untrackedLines.unscoredFiles
    return counts
  }

  /// `diff-index`, as `diff HEAD` writes a new index the watcher reads as a
  /// change. Before the first commit, from the empty tree; see worktrees.md.
  private func numstatSinceLastCommit(in path: URL, options: [String]) async -> String? {
    let diffIndex = ["--no-optional-locks", "diff-index"] + options
    if let output = await runner.output(diffIndex + ["HEAD"], in: path) { return output }
    // Only where HEAD is unborn: after any other failure the empty tree would
    // count the whole checkout as added.
    guard !(await runner.succeeds(["rev-parse", "--verify", "--quiet", "HEAD"], in: path)),
      let emptyTree = await runner.output(["hash-object", "-t", "tree", "/dev/null"], in: path)
    else { return nil }
    return await runner.output(
      diffIndex + [emptyTree.trimmingCharacters(in: .whitespacesAndNewlines)],
      in: path,
    )
  }

  /// The reads block, on a dead mount until it times out, so they run on
  /// Dispatch and not on a cooperative pool thread; see worktrees.md.
  private func untrackedCounts(in path: URL) async -> LineCounts {
    guard
      let output = await runner.output(
        ["--no-optional-locks", "ls-files", "--others", "--exclude-standard", "-z"],
        in: path,
      )
    else { return LineCounts() }
    let paths = NulPathListParser.parse(output, limit: UntrackedLineCounter.fileLimit)
    guard !paths.isEmpty else { return LineCounts() }
    let memo = readState.untrackedMemo
    return await runOnDispatch { UntrackedLineCounter.count(paths: paths, in: path, memo: memo) }
  }
}
