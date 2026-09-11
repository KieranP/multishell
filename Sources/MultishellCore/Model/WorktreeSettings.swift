import Foundation

/// Where worktrees go and how their branches are named: both the app-wide
/// defaults and a project's effective settings. Never read `ProjectSettings`.
public struct WorktreeSettings: Codable, Hashable, Sendable {
  /// Directory that will hold a project's worktrees. Absolute, or relative
  /// to the repository root. `~` and `{project}` are expanded.
  public var worktreeDirectory: String

  /// Prepended to branch names typed in the new-worktree sheet.
  public var branchPrefix: String

  public static let defaultWorktreeDirectory = "../{project}-worktrees"

  public init(
    worktreeDirectory: String = WorktreeSettings.defaultWorktreeDirectory,
    branchPrefix: String = ""
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    worktreeDirectory = try container.decode(
      String.self, forKey: .worktreeDirectory, or: Self.defaultWorktreeDirectory)
    branchPrefix = try container.decode(String.self, forKey: .branchPrefix, or: "")
  }
}

// MARK: - Resolution

extension WorktreeSettings {
  /// Applies `branchPrefix`, without doubling it if the user typed it.
  public func qualifiedBranch(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !branchPrefix.isEmpty, !trimmed.hasPrefix(branchPrefix) else { return trimmed }
    return branchPrefix + trimmed
  }

  /// The directory new worktrees are created in. Blank is the default: an
  /// empty path resolves to the repository itself.
  public func worktreeContainer(for project: Project) -> URL {
    let text = worktreeDirectory.trimmingCharacters(in: .whitespaces)
    let expanded =
      (text.isEmpty ? Self.defaultWorktreeDirectory : text)
      .replacingOccurrences(of: "{project}", with: project.name)
    return URL(
      fileURLWithPath: Self.expandingTilde(expanded), isDirectory: true, relativeTo: project.path
    )
    .standardizedFileURL
  }

  /// Where a branch's worktree goes: the container plus a slug, always
  /// strictly inside it, this path being shown before git is asked.
  public func worktreePath(forBranch branch: String, in project: Project) -> URL {
    var slug =
      branch
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: " ", with: "-")
    if slug.isEmpty || slug == "." || slug == ".." { slug = "_" }
    return worktreeContainer(for: project).appendingPathComponent(slug, isDirectory: true)
  }

  /// `NSString.expandingTildeInPath` is not dependable off Darwin.
  private static func expandingTilde(_ path: String) -> String {
    guard path == "~" || path.hasPrefix("~/") else { return path }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return home + path.dropFirst(1)
  }
}
