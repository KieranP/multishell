import Foundation

/// A git repository the user has added to the sidebar. Identity is the path;
/// see Docs/design/architecture.md.
public struct Project: Identifiable, Codable, Hashable, Sendable {
  /// Always the normalised form from `URL.normalizedDirectory`, so `id` can
  /// read it directly rather than standardise again on every comparison.
  public private(set) var path: URL
  public var isExpanded: Bool
  /// The user's own, as the settings forms edit them.
  public var settings: ProjectSettings
  /// What the repository's `.multishell.json` said when last read. Per run,
  /// so it is in neither `CodingKeys` nor `==`; see settings.md.
  public var sharedSettings: SharedSettingsSnapshot = .unread

  public var id: String { path.path }

  /// The folder name, less a bare repository's `.git` suffix. One hidden
  /// beside its worktrees takes the name of the folder holding it.
  public var name: String {
    let folder = path.lastPathComponent
    let base = folder.hasSuffix(".git") ? String(folder.dropLast(4)) : folder
    if base.isEmpty || base.hasPrefix(".") {
      return path.deletingLastPathComponent().lastPathComponent
    }
    return base
  }

  public init(path: URL, isExpanded: Bool = true, settings: ProjectSettings = ProjectSettings()) {
    self.path = path.normalizedDirectory
    self.isExpanded = isExpanded
    self.settings = settings
  }

  /// `sharedSettings` is this run's read of a file, so it is neither written
  /// nor compared: a restored one would trust a file nobody looked at.
  enum CodingKeys: String, CodingKey {
    case path, isExpanded, settings
  }

  public static func == (a: Project, b: Project) -> Bool {
    a.path == b.path && a.isExpanded == b.isExpanded && a.settings == b.settings
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(path)
    hasher.combine(isExpanded)
    hasher.combine(settings)
  }

  /// Decoded with defaults so state written by an older build still loads
  /// when a setting is added.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.path = try container.decode(URL.self, forKey: .path).normalizedDirectory
    self.isExpanded = try container.decode(Bool.self, forKey: .isExpanded, or: true)
    self.settings = try container.decode(
      ProjectSettings.self, forKey: .settings, or: ProjectSettings())
  }
}
