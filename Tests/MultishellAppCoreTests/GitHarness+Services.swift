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
    connectServices(to: model)
  }

  /// The same for a model of the test's own, such as one on a fake git.
  @discardableResult
  func connectServices(
    to model: AppModel<FakeSurface>
  ) -> (host: FakePullRequestHost, provider: FakeCIProvider) {
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
