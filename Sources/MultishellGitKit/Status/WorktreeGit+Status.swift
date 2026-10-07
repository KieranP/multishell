import Foundation
import MultishellCore

/// What a worktree holds against its branch, for the sidebar's badges.
extension WorktreeGit {
  /// `--no-optional-locks`: a plain `git status` takes `index.lock`, and this
  /// polls, so a `git commit` typed at the wrong moment would fail.
  func status(
    of worktree: Worktree, counting indicator: GitStatusIndicator = .default
  )
    async throws -> WorktreeStatus
  {
    let output = try await runner.run(
      ["--no-optional-locks", "status", "--porcelain=v1", "--branch"], in: worktree.path)
    var status = WorktreeStatusParser.parse(output)
    guard status.isDirty else { return status }
    let counts = await lineCounts(
      in: worktree.path, counting: indicator, untrackedCount: status.untracked)
    status.insertions = counts.insertions
    status.deletions = counts.deletions
    status.unscoredFiles = counts.unscoredFiles
    return status
  }

  /// `--cached` is the index alone, and the fallback wherever the diff
  /// against HEAD fails, which an unborn HEAD does; see worktrees.md.
  private func lineCounts(
    in path: URL, counting indicator: GitStatusIndicator, untrackedCount: Int
  ) async -> LineCounts {
    // `--diff-filter=u` drops unmerged paths, which print `0 0` from
    // `--cached` and read as a file with nothing to count.
    let numstat = ["--no-optional-locks", "diff", "--numstat", "--diff-filter=u"]
    var counts = LineCounts()
    if indicator == .stagedAndUnstaged,
      let output = await runner.output(numstat + ["HEAD"], in: path)
    {
      counts = NumstatParser.parse(output)
    } else if let cached = await runner.output(numstat + ["--cached"], in: path) {
      counts = NumstatParser.parse(cached)
    }
    guard indicator == .stagedAndUnstaged, untrackedCount > 0 else { return counts }
    let untrackedLines = await untrackedCounts(in: path)
    counts.insertions += untrackedLines.insertions
    counts.unscoredFiles += untrackedLines.unscoredFiles
    return counts
  }

  /// The reads block, on a dead mount until it times out, so they run on
  /// Dispatch and not on a cooperative pool thread; see worktrees.md.
  private func untrackedCounts(in path: URL) async -> LineCounts {
    guard
      let output = await runner.output(
        ["--no-optional-locks", "ls-files", "--others", "--exclude-standard", "-z"], in: path)
    else { return LineCounts() }
    let paths = NulPathListParser.parse(output, limit: UntrackedLineCounter.fileLimit)
    guard !paths.isEmpty else { return LineCounts() }
    let memo = readState.untrackedMemo
    return await runOnDispatch { UntrackedLineCounter.count(paths: paths, in: path, memo: memo) }
  }
}
