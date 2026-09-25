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
      in: worktree.path, counting: indicator, untracked: status.untracked)
    status.insertions = counts.insertions
    status.deletions = counts.deletions
    status.unscoredFiles = counts.unscored
    return status
  }

  /// `--cached` is the index alone, and the fallback wherever the diff
  /// against HEAD fails, which an unborn HEAD does; see worktrees.md.
  private func lineCounts(
    in path: URL, counting indicator: GitStatusIndicator, untracked: Int
  ) async -> LineCounts {
    // `--diff-filter=u` drops unmerged paths, which print `0 0` from
    // `--cached` and read as a file with nothing to count.
    let numstat = ["--no-optional-locks", "diff", "--numstat", "--diff-filter=u"]
    var counts = LineCounts()
    if indicator == .stagedAndUnstaged,
      let output = await runner.output(numstat + ["HEAD"], in: path)
    {
      counts = DiffStatParser.parse(output)
    } else if let cached = await runner.output(numstat + ["--cached"], in: path) {
      counts = DiffStatParser.parse(cached)
    }
    guard indicator == .stagedAndUnstaged, untracked > 0 else { return counts }
    let loose = await untrackedCounts(in: path)
    counts.insertions += loose.lines
    counts.unscored += loose.unscored
    return counts
  }

  /// The reads block, on a dead mount until it times out. Detached keeps them off
  /// the main actor but not off the cooperative pool; see worktrees.md.
  private func untrackedCounts(in path: URL) async -> (lines: Int, unscored: Int) {
    guard
      let output = await runner.output(
        ["--no-optional-locks", "ls-files", "--others", "--exclude-standard", "-z"], in: path)
    else { return (0, 0) }
    let paths = UntrackedLineCounter.paths(from: output)
    guard !paths.isEmpty else { return (0, 0) }
    let memo = shared.untrackedMemo
    return await Task.detached(priority: .utility) {
      UntrackedLineCounter.count(paths: paths, in: path, memo: memo)
    }.value
  }
}
