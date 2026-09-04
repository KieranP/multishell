import Foundation

/// A git repository the user has added to the sidebar.
///
/// Identity is the repository path, not a generated id: adding the same
/// directory twice is the same project, and a persisted project still
/// resolves after the app forgets its in-memory state.
public struct Project: Identifiable, Codable, Hashable, Sendable {
  /// Always the normalised form from `directory`, so `id` can read it
  /// directly rather than standardise again on every comparison.
  public private(set) var path: URL
  public var isExpanded: Bool
  public var settings: ProjectSettings

  public var id: String { path.path }
  public var name: String { path.lastPathComponent }

  public init(path: URL, isExpanded: Bool = true, settings: ProjectSettings = ProjectSettings()) {
    self.path = Self.directory(path)
    self.isExpanded = isExpanded
    self.settings = settings
  }

  /// A directory URL whether or not the directory exists right now.
  /// `URL(fileURLWithPath:)` alone asks the filesystem, and a relative
  /// worktree path resolved against a project URL that Foundation took for a
  /// file lands in the parent directory instead.
  static func directory(_ url: URL) -> URL {
    URL(fileURLWithPath: url.path, isDirectory: true).standardizedFileURL
  }

  /// Decoded with defaults so state written by an older build still loads
  /// when a setting is added.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.path = Self.directory(try container.decode(URL.self, forKey: .path))
    self.isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
    self.settings =
      try container.decodeIfPresent(ProjectSettings.self, forKey: .settings) ?? ProjectSettings()
  }
}
