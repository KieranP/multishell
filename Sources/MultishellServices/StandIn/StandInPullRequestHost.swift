import Foundation

/// A pull request host that answers from a stand-in, the same for any directory.
/// Opening a page or merging does nothing: a stand-in pull request has no host.
struct StandInPullRequestHost: PullRequestHost {
  let standIn: ServiceStandIn

  func pullRequests(in directory: URL) async throws -> [PullRequest] {
    standIn.pullRequests
  }

  func pullRequests(headedBy branch: String, in directory: URL) async throws -> [PullRequest] {
    standIn.pullRequests.filter { $0.headBranch == branch }
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

  func mergeOptions(
    of pullRequest: PullRequest,
    in directory: URL,
  ) async throws -> PullRequestMergeOptions {
    throw ServiceReadFailure.failed("a stand-in pull request has no repository to merge in")
  }

  func merge(
    _ pullRequest: PullRequest,
    as merge: PullRequestMerge,
    in directory: URL,
  ) async throws {}

  func disableAutoMerge(of pullRequest: PullRequest, in directory: URL) async throws {}

  func toolStatus() async -> ServiceToolStatus {
    .ready(version: ServiceStandIn.toolVersion, account: nil)
  }
}
