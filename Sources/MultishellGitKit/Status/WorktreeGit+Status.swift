import Foundation
import MultishellCore

/// What a worktree holds against its branch, for the sidebar's badges and the
/// Files panel; one list of changes, every count a sum over it.
extension WorktreeGit {
  /// How many paths a read keeps for the Files panel, of new files and of
  /// ignored entries alike. Every new file is still counted; see files.md.
  static let listedPathLimit = 50_000

  /// `--diff-filter=u` drops unmerged paths, which print `0 0`. Renames and the
  /// algorithm are set here so a user's own git config cannot move the counts.
  private static func numstatOptions(_ algorithm: DiffAlgorithm) -> [String] {
    [
      "--numstat", "-z", "--diff-filter=u", "--no-renames",
      "--diff-algorithm=\(algorithm.rawValue)",
    ]
  }

  func status(
    of worktree: Worktree,
    counting indicator: GitStatusIndicator = .default,
    diffAlgorithm: DiffAlgorithm = .default,
  )
    async throws -> WorktreeStatus
  {
    try await status(
      inRepositoryAt: worktree.path,
      counting: indicator,
      diffAlgorithm: diffAlgorithm,
    )
  }

  /// Any repository's checkout, a submodule the Files panel opens too. Its index reads pass
  /// `--no-optional-locks`, as a plain `git status` takes `index.lock` and fails a `git commit`.
  public func status(
    inRepositoryAt path: URL,
    counting indicator: GitStatusIndicator,
    diffAlgorithm: DiffAlgorithm,
  )
    async throws -> WorktreeStatus
  {
    let output = try await runner.run(
      ["--no-optional-locks", "status", "--porcelain=v1", "-z", "--branch", "--no-renames"],
      in: path,
    )
    var (status, entries) = WorktreeStatusParser.parse(output)
    guard status.isDirty else { return status }
    let tracked = entries.filter { !$0.isUntracked }
    var changes = await trackedChanges(
      tracked,
      in: path,
      counting: indicator,
      diffAlgorithm: diffAlgorithm,
    )
    // Kept at status's collapsed count where the list fails, so a tree with new
    // files never reads as clean.
    if tracked.count < entries.count, let untracked = await untrackedFiles(in: path) {
      status.untracked = untracked.count
      status.changedFiles = tracked.count + untracked.count
      status.untrackedPaths = untracked.paths
      if indicator == .stagedAndUnstaged {
        changes += await untrackedChanges(untracked.paths, in: path)
      }
    }
    status.setChanges(changes)
    return status
  }

  /// Joined to status by path. `--cached` under Staged Only, and the fallback
  /// where the count since the last commit fails; see worktrees.md.
  private func trackedChanges(
    _ entries: [StatusEntry],
    in path: URL,
    counting indicator: GitStatusIndicator,
    diffAlgorithm: DiffAlgorithm,
  ) async -> [StatusChange] {
    let options = Self.numstatOptions(diffAlgorithm)
    let cachedOnly = ["--no-optional-locks", "diff"] + options + ["--cached"]
    var linesByPath: [String: StatusChange.Lines] = [:]
    if indicator == .stagedAndUnstaged,
      let output = await numstatSinceLastCommit(in: path, options: options)
    {
      linesByPath = NumstatParser.parse(output)
    } else if let cached = await runner.output(cachedOnly, in: path) {
      linesByPath = NumstatParser.parse(cached)
    }
    let counted = indicator == .stagedOnly ? entries.filter(\.isStaged) : entries
    return counted.map { entry in
      StatusChange(
        path: entry.path,
        kind: entry.changeKind(counting: indicator),
        lines: entry.isUnmerged ? .notCounted : linesByPath[entry.path] ?? .notCounted,
      )
    }
  }

  /// `diff-index`, as `diff HEAD` writes a new index the watcher reads as a
  /// change. Before the first commit, from the empty tree; see worktrees.md.
  private func numstatSinceLastCommit(in path: URL, options: [String]) async -> String? {
    let diffIndex = ["--no-optional-locks", "diff-index"] + options
    if let output = await runner.output(diffIndex + ["HEAD"], in: path) { return output }
    // Only where HEAD is unborn: after any other failure the empty tree would
    // count the whole checkout as added.
    guard !(await hasCommits(in: path)),
      let emptyTree = await emptyTreeID(in: path)
    else { return nil }
    return await runner.output(diffIndex + [emptyTree], in: path)
  }

  /// Every new file, as `-uall` lists them without costing the untracked
  /// cache; only the first `listedPathLimit` become strings.
  private func untrackedFiles(in path: URL) async -> (count: Int, paths: [String])? {
    guard
      let output = await runner.output(
        ["--no-optional-locks", "ls-files", "--others", "--exclude-standard", "-z"],
        in: path,
      )
    else { return nil }
    return (
      NulPathListParser.count(output),
      NulPathListParser.parse(output, limit: Self.listedPathLimit),
    )
  }

  /// The reads block, on a dead mount until it times out, so they run on
  /// Dispatch and not on a cooperative pool thread; see worktrees.md.
  private func untrackedChanges(_ paths: [String], in path: URL) async -> [StatusChange] {
    guard !paths.isEmpty else { return [] }
    let memo = readState.untrackedMemo
    let lines = await runOnDispatch {
      UntrackedLineCounter.count(paths: paths, in: path, memo: memo)
    }
    return zip(paths, lines).map { path, lines in
      StatusChange(path: path, kind: .added, lines: lines)
    }
  }
}
