import Foundation

/// One check on a pull request's head, as its host lists it: a CI job, a
/// status a bot posted, a scan.
public struct PullRequestCheck: Hashable, Sendable {
  public let name: String
  /// The workflow it belongs to, where the host groups checks.
  public let workflow: String?
  /// Skipped reads as cancelled: neither passed nor failed.
  public let status: CIRunStatus
  /// The base branch's rules require it to pass before a merge.
  public let isRequired: Bool
  public let link: URL?
}
