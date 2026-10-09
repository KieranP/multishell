import Foundation

extension WorktreeSettings {
  /// `~` and `~/` only, where `expandingTildeInPath` would also take `~name`
  /// to that user's home.
  private static func expandingTilde(_ path: String) -> String {
    guard path == "~" || path.hasPrefix("~/") else { return path }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return home + path.dropFirst(1)
  }

  /// The directory new worktrees are created in. Blank is the default: an
  /// empty path resolves to the repository itself.
  public func worktreeContainer(for project: Project) -> URL {
    let expanded = (worktreeDirectory.trimmedOrNil ?? Self.defaultWorktreeDirectory)
      .replacingOccurrences(of: "{project}", with: project.name)
    return URL(
      fileURLWithPath: Self.expandingTilde(expanded),
      isDirectory: true,
      relativeTo: project.path,
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
}
