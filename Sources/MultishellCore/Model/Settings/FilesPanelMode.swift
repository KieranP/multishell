/// What the Files panel lists: every file, or what git says changed. One saved
/// choice for every worktree; the raw values are what earlier builds wrote.
public enum FilesPanelMode: String, Codable, Hashable, Sendable {
  case files = "all"
  case git = "modified"

  public static let `default` = Self.files
}
