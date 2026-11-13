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

  /// A stand-in has no host to follow a rename on, so the URL's own.
  func repository(namedBy remoteURL: String, in directory: URL) async throws -> RemoteRepository {
    guard let repository = RemoteRepository(remoteURL: remoteURL) else {
      throw ServiceReadFailure.notHosted
    }
    return repository
  }

  func checks(of pullRequest: PullRequest, in directory: URL) async throws -> [PullRequestCheck] {
    standIn.checks[ServiceStandIn.key(of: pullRequest)] ?? []
  }

  /// A stand-in's pull requests move only as its list says.
  func headCommit(of pullRequest: PullRequest, in directory: URL) async throws -> String {
    pullRequest.headCommit
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
