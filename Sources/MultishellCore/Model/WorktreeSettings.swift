import Foundation

/// Where worktrees go and how their branches are named.
///
/// One value type serves two roles: the app-wide defaults in
/// `Workspace.worktreeDefaults`, and the effective settings for a project after
/// its overrides are applied. Every path and branch decision reads from an
/// instance of this, never from `ProjectSettings` directly.
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
    worktreeDirectory =
      try container.decodeIfPresent(String.self, forKey: .worktreeDirectory)
      ?? Self.defaultWorktreeDirectory
    branchPrefix = try container.decodeIfPresent(String.self, forKey: .branchPrefix) ?? ""
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

  /// The directory new worktrees are created in. Blank means the default:
  /// an empty path would resolve to the repository itself, and a worktree
  /// inside the main checkout is never what anyone meant.
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

  /// Where a branch's worktree goes: the container, plus a slug of the
  /// branch name so `feat/tabs` cannot try to nest a directory.
  ///
  /// The result is always strictly inside the container. git refuses `.`
  /// and `..` as branch names, but this path is shown, and its parent
  /// created, before git is asked.
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
