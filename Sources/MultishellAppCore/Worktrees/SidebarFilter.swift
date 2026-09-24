import Foundation
import MultishellCore

/// What the sidebar shows for a filter string. A project matching keeps all
/// its worktrees; matching folds case and accents, never by one alphabet.
public struct SidebarFilter: Sendable {
  public struct Entry: Equatable, Sendable {
    public let project: Project
    public let worktrees: [Worktree]
    public let forcedOpen: Bool
  }

  public let needle: String

  public init(_ text: String) {
    needle = text.trimmingCharacters(in: .whitespaces)
  }

  public var isActive: Bool { !needle.isEmpty }

  public func apply(to workspace: Workspace) -> [Entry] {
    // One pass over the worktrees, not one per project; grouping keeps order.
    let byProject = Dictionary(grouping: workspace.worktrees, by: \.projectID)
    return workspace.projects.compactMap { project in
      let worktrees = byProject[project.id] ?? []
      guard isActive else {
        return Entry(project: project, worktrees: worktrees, forcedOpen: false)
      }
      if project.name.foldedContains(needle) {
        return Entry(project: project, worktrees: worktrees, forcedOpen: true)
      }
      let matching = worktrees.filter { names($0, in: workspace) }
      return matching.isEmpty ? nil : Entry(project: project, worktrees: matching, forcedOpen: true)
    }
  }

  private func names(_ worktree: Worktree, in workspace: Workspace) -> Bool {
    worktree.name.foldedContains(needle)
      || workspace.displayName(of: worktree).foldedContains(needle)
  }
}
