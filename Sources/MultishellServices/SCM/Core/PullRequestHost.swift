import Foundation

/// Where a repository's pull requests live, read through the host's own
/// tool. GitHub's is the one there is; see Docs/design/services.md.
public protocol PullRequestHost: Sendable {
  /// Pull requests of the repository at `directory`, open or not, newest
  /// first, as many as one call returns. Throws `ServiceReadFailure`.
  func pullRequests(in directory: URL) async throws -> [PullRequest]

  /// The checks on the pull request's head, each once, and which are required.
  func checks(of pullRequest: PullRequest, in directory: URL) async throws -> [PullRequestCheck]

  /// Opens the pull request in the browser.
  func open(_ pullRequest: PullRequest, in directory: URL) async throws

  /// Opens the host's page for a new pull request of `head`, already pushed
  /// to `headRepository`, into `base`.
  func openNewPullRequest(
    head: String,
    in headRepository: RemoteRepository?,
    base: String,
    directory: URL,
  ) async throws

  /// The methods the repository allows, the default and the host's messages.
  /// Throws `ServiceReadFailure`.
  func mergeOptions(
    of pullRequest: PullRequest,
    in directory: URL,
  ) async throws -> PullRequestMergeOptions

  /// Merges it, or turns auto-merge on; the app's second write to a remote.
  func merge(
    _ pullRequest: PullRequest,
    as merge: PullRequestMerge,
    in directory: URL,
  ) async throws

  func disableAutoMerge(of pullRequest: PullRequest, in directory: URL) async throws

  func toolStatus() async -> ServiceToolStatus
}
