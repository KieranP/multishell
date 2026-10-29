import Foundation

/// A pull request host that answers from a stand-in, the same for any directory.
/// Opening a page does nothing: a stand-in pull request has none.
struct StandInPullRequestHost: PullRequestHost {
  let standIn: ServiceStandIn

  func pullRequests(in directory: URL) async throws -> [PullRequest] {
    standIn.pullRequests
  }

  func checks(of pullRequest: PullRequest, in directory: URL) async throws -> [PullRequestCheck] {
    standIn.checks[ServiceStandIn.key(of: pullRequest)] ?? []
  }

  func open(_ pullRequest: PullRequest, in directory: URL) async throws {}

  func openNewPullRequest(
    head: String,
    in headRepository: RemoteRepository?,
    base: String,
    directory: URL,
  ) async throws {}

  func toolStatus() async -> ServiceToolStatus {
    .ready(version: ServiceStandIn.toolVersion, account: nil)
  }
}
