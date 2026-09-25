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

  public func localBranches(_ project: Project) async throws -> [String] {
    let output = try await runner.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"],
      in: project.path
    )
    return output.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// Remote branches with the symbolic `origin/HEAD` dropped. Full ref names,
  /// `%(refname:short)` abbreviating that one to `origin`.
  public func remoteBranches(_ project: Project) async throws -> [String] {
    let output = try await runner.run(
      ["for-each-ref", "--format=%(refname)", "refs/remotes"],
      in: project.path
    )
    let prefix = BranchRef.remotePrefix
    return output.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.hasPrefix(prefix) && !$0.hasSuffix("/HEAD") }
      .map { String($0.dropFirst(prefix.count)) }
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
