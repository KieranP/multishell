import MultishellCore

/// What the sidebar shows for a filter string.
///
/// A project whose own name matches keeps all its worktrees; otherwise only
/// worktrees whose name matches remain and the project is forced open. A
/// renamed worktree matches on either name: the user may remember the one
/// they typed or the branch under it. Pure, so the rules are tested without
/// a view.
public struct SidebarFilter: Sendable {
  public struct Entry: Equatable, Sendable {
    public let project: Project
    public let worktrees: [Worktree]
    public let forcedOpen: Bool
  }

  public let needle: String

  public init(_ text: String) {
    needle = text.trimmingCharacters(in: .whitespaces).lowercased()
  }

  public var isActive: Bool { !needle.isEmpty }

  public func apply(to workspace: Workspace) -> [Entry] {
    workspace.projects.compactMap { project in
      let worktrees = workspace.worktrees(of: project.id)
      guard isActive else {
        return Entry(project: project, worktrees: worktrees, forcedOpen: false)
      }
      if project.name.lowercased().contains(needle) {
        return Entry(project: project, worktrees: worktrees, forcedOpen: true)
      }
      let matching = worktrees.filter {
        $0.name.lowercased().contains(needle)
          || workspace.displayName(of: $0).lowercased().contains(needle)
      }
      return matching.isEmpty ? nil : Entry(project: project, worktrees: matching, forcedOpen: true)
    }
  }
}
