/// What the Files panel shows, one saved choice for every worktree; the raw
/// values are what earlier builds wrote.
public enum FilesPanelMode: String, CaseIterable, Codable, Hashable, Sendable {
  case changes = "modified"
  case ciRuns = "ci"
  case files = "all"
  case pullRequest = "pull-request"

  public static let `default` = Self.files

  /// Files and Changes list files; the other two are the services' pages.
  public var listsFiles: Bool { self == .files || self == .changes }
}
