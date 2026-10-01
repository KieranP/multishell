import Foundation
import MultishellCore

/// What the sidebar shows for a filter string. A project matching keeps all
/// its worktrees; matching folds case and accents, never by one alphabet.
public struct SidebarFilter: Sendable {
  public struct Entry: Equatable, Sendable {
    public let project: Project
    public let worktrees: [Worktree]
    /// What the chevron and the rows show: while the filter has text it holds
    /// every project open, bar those folded under it.
    public let isExpanded: Bool
  }

  let searchText: String

  public init(_ text: String) {
    searchText = text.trimmingCharacters(in: .whitespaces)
  }

  public var isActive: Bool { !searchText.isEmpty }

  func apply(to workspace: Workspace, folding folded: Set<Project.ID> = []) -> [Entry] {
    // One pass over the worktrees, not one per project; grouping keeps order.
    let byProject = Dictionary(grouping: workspace.worktrees, by: \.projectID)
    return workspace.projects.compactMap { project in
      let worktrees = byProject[project.id] ?? []
      guard isActive else {
        return Entry(project: project, worktrees: worktrees, isExpanded: project.isExpanded)
      }
      let isExpanded = !folded.contains(project.id)
      if project.name.foldedContains(searchText) {
        return Entry(project: project, worktrees: worktrees, isExpanded: isExpanded)
      }
      let matching = worktrees.filter { matches($0, in: workspace) }
      return matching.isEmpty
        ? nil : Entry(project: project, worktrees: matching, isExpanded: isExpanded)
    }
  }

  private func matches(_ worktree: Worktree, in workspace: Workspace) -> Bool {
    worktree.name.foldedContains(searchText)
      || workspace.displayName(of: worktree).foldedContains(searchText)
  }
}
