import Foundation

/// A git repository the user has added to the sidebar. Identity is the path;
/// see docs/design/architecture.md.
public struct Project: Identifiable, Codable, Hashable, Sendable {
  /// Always the normalised form from `directory`, so `id` can read it
  /// directly rather than standardise again on every comparison.
  public private(set) var path: URL
  public var isExpanded: Bool
  public var settings: ProjectSettings

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
    self.path = Self.directory(path)
    self.isExpanded = isExpanded
    self.settings = settings
  }

  /// A directory URL whether or not it exists now: `URL(fileURLWithPath:)`
  /// asks the filesystem, and a missing one resolves as a file.
  static func directory(_ url: URL) -> URL {
    URL(fileURLWithPath: url.path, isDirectory: true).standardizedFileURL
  }

  /// Decoded with defaults so state written by an older build still loads
  /// when a setting is added.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.path = Self.directory(try container.decode(URL.self, forKey: .path))
    self.isExpanded = try container.decode(Bool.self, forKey: .isExpanded, or: true)
    self.settings = try container.decode(
      ProjectSettings.self, forKey: .settings, or: ProjectSettings())
  }
}
