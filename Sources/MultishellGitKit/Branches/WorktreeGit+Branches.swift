import Foundation
import MultishellCore

/// Reading, fetching and deleting branches.
extension WorktreeGit {
  /// Every branch with its tip, upstream and date, in one process, the date
  /// atom retried separately. `nil` is a failed read, not no branches.
  func branchRefs(_ project: Project) async -> [BranchRef]? {
    if let output = await runner.output(Self.refQuery(withDates: true), in: project.path) {
      return BranchRefParser.parse(output)
    }
    guard let output = await runner.output(Self.refQuery(withDates: false), in: project.path) else {
      return nil
    }
    return BranchRefParser.parse(output)
  }

  private static func refQuery(withDates: Bool) -> [String] {
    var format = [
      "%(refname)", "%(objectname)", "%(upstream)", "%(upstream:track)", "%(symref)",
    ]
    if withDates { format.append("%(committerdate:unix)") }
    return [
      "for-each-ref", "--format=" + format.joined(separator: "%09"), "refs/heads", "refs/remotes",
    ]
  }

  /// `git fetch --prune`, on the user's click only: the one git call here
  /// that talks to a network. `GIT_TERMINAL_PROMPT=0`, and a timeout.
  public func fetch(_ project: Project, timeout: Duration = .seconds(120)) async throws {
    _ = try await runner.run(
      ["fetch", "--prune", "--quiet"], in: project.path,
      environment: ["GIT_TERMINAL_PROMPT": "0"], timeout: timeout)
  }

  /// The names a new worktree can start from, symbolic refs such as
  /// `origin/HEAD` dropped. `nil` is a failed read.
  public func branchNames(_ project: Project) async -> (local: [String], remote: [String])? {
    guard let refs = await branchRefs(project)?.filter({ $0.symref == nil }) else { return nil }
    return (refs.filter(\.isLocal).map(\.shortName), refs.filter(\.isRemote).map(\.shortName))
  }

  public func currentBranch(_ project: Project) async throws -> String {
    try await runner.run(["rev-parse", "--abbrev-ref", "HEAD"], in: project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Only `--verify --quiet`'s exit 1 says missing: a git that failed any other
  /// way says nothing, and the caller would `branch -D` on the answer.
  func lacksBranch(_ branch: String, in project: Project) async -> Bool {
    await runner.exitStatus(
      ["rev-parse", "--verify", "--quiet", BranchRef.localRef(branch)], in: project.path) == 1
  }

  /// `-D`, a branch cut from another start point being unmerged into HEAD.
  /// Kept where a worktree still lists it, as a SIGKILL can leave the record.
  func deleteBranchIfUnlisted(_ branch: String, in project: Project) async {
    guard let listed = try? await list(project), !listed.contains(where: { $0.branch == branch })
    else { return }
    _ = try? await runner.run(["branch", "-D", branch], in: project.path)
  }

  /// `git branch -d`, which refuses a branch with commits no other branch
  /// has; `force` is `-D`.
  func deleteBranch(_ branch: String, force: Bool = false, in project: Project) async throws {
    _ = try await runner.run(["branch", force ? "-D" : "-d", branch], in: project.path)
  }
}
