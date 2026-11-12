/// What the Files panel shows, one saved choice for every worktree; the raw
/// values are what earlier builds wrote.
public enum FilesPanelMode: String, CaseIterable, Codable, Hashable, Sendable {
  case changes = "modified"
  case ciRuns = "ci"
  case files = "all"
  case pullRequest = "pull-request"
  case review = "review"

  public static let `default` = Self.files

  /// Files and Changes list files; Review lists comments, the others are the services' pages.
  public var listsFiles: Bool { self == .files || self == .changes }

  /// A pull request's or CI's page, read from the services rather than git.
  public var isServicePage: Bool { self == .pullRequest || self == .ciRuns }
}
