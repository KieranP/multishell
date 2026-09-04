import MultishellCore

/// What the sidebar shows for a filter string.
///
/// A project whose own name matches keeps all its worktrees; otherwise only
/// matching branches remain and the project is forced open. Pure, so the
/// rules are tested without a view.
struct SidebarFilter {
  struct Entry: Equatable {
    let project: Project
    let worktrees: [Worktree]
    let forcedOpen: Bool
  }

  let needle: String

  init(_ text: String) {
    needle = text.trimmingCharacters(in: .whitespaces).lowercased()
  }

  var isActive: Bool { !needle.isEmpty }

  func apply(to workspace: Workspace) -> [Entry] {
    workspace.projects.compactMap { project in
      let worktrees = workspace.worktrees(of: project.id)
      guard isActive else {
        return Entry(project: project, worktrees: worktrees, forcedOpen: false)
      }
      if project.name.lowercased().contains(needle) {
        return Entry(project: project, worktrees: worktrees, forcedOpen: true)
      }
      let matching = worktrees.filter { $0.name.lowercased().contains(needle) }
      return matching.isEmpty ? nil : Entry(project: project, worktrees: matching, forcedOpen: true)
    }
  }
}
