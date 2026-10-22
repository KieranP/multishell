/// What the Files panel lists: every file, or what changed. One saved choice
/// for every worktree, so raw values never change.
public enum FilesPanelMode: String, Codable, Hashable, Sendable {
  case all
  case modified

  public static let `default` = Self.all
}
