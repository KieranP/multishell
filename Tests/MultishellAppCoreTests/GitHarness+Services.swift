import Foundation
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

extension GitHarness {
  static let gitHubOrigin = "git@github.com:me/demo.git"

  /// Fakes in place of `gh` and `circleci`, which a real run would reach
  /// the developer's own accounts with.
  @discardableResult
  func connectServices() -> (host: FakePullRequestHost, provider: FakeCIProvider) {
    let host = FakePullRequestHost()
    let provider = FakeCIProvider()
    model.remoteState.connections = ServiceConnections(
      pullRequestHosts: [.gitHub: host],
      ciProviders: [.circleCI: provider],
    )
    return (host, provider)
  }

  /// A bare `origin` beside the repository, pushed to by path.
  func addOrigin() async throws {
    try await TestRepository.addOrigin(to: project.path, in: root, using: git)
  }

  /// Pushed with `-u` by path, then `origin` set to GitHub's spelling, which
  /// matching a pull request needs for its owner.
  func pushToGitHubOrigin(_ worktree: Worktree) async throws {
    let branch = try #require(worktree.branch)
    _ = try await git.run(["push", "-q", "-u", "origin", branch], in: worktree.path)
    _ = try await git.run(["remote", "set-url", "origin", Self.gitHubOrigin], in: project.path)
  }

  func commitFile(_ file: String, in worktree: Worktree) async throws {
    try "\(file)\n".write(
      to: worktree.path.appendingPathComponent(file),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await git.run(["add", file], in: worktree.path)
    _ = try await git.run(["commit", "-q", "-m", file], in: worktree.path)
  }

  /// Another branch's work, then `head`'s squashed, off `main` and on no branch:
  /// what a trunk holds after the pull request at `head` is squash-merged.
  func squashOnSideBranch(of head: String) async throws -> String {
    _ = try await git.run(["checkout", "-q", "-b", "side", "main"], in: project.path)
    _ = try await git.run(["commit", "-q", "--allow-empty", "-m", "other"], in: project.path)
    _ = try await git.run(["checkout", "-q", head, "--", "."], in: project.path)
    _ = try await git.run(["commit", "-q", "-m", "squashed"], in: project.path)
    let tip = try await git.run(["rev-parse", "HEAD"], in: project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    _ = try await git.run(["checkout", "-q", "main"], in: project.path)
    _ = try await git.run(["branch", "-q", "-D", "side"], in: project.path)
    return tip
  }

  func tip(of worktree: Worktree) async throws -> String {
    try await git.run(["rev-parse", "HEAD"], in: worktree.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// No services read pending, under way or queued behind one, so a count of
  /// calls is final.
  func servicesAreSettled() -> Bool {
    let state = model.remoteState
    return state.pendingReads[project.id] == nil && !state.readLog.isAsking(project.id)
      && state.rereads[project.id] == nil
  }

  /// The fake provider's configuration file, which says the repository runs on it.
  func writeCIConfiguration() throws {
    try "".write(
      to: project.path.appendingPathComponent(".fake-ci.yml"),
      atomically: true,
      encoding: .utf8,
    )
  }
}
