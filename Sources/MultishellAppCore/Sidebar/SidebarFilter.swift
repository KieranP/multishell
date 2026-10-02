import Foundation
import MultishellCore

/// What the sidebar shows for a filter string. A project matching keeps all
/// its worktrees; matching folds case and accents, never by one alphabet.
public struct SidebarFilter: Sendable {
  public struct Entry: Equatable, Sendable {
    public let project: Project
    public let worktrees: [Worktree]
    /// What the chevron and the rows show: while the filter has text it holds
    /// every project open, bar those collapsed under it.
    public let isExpanded: Bool
  }

  private let filterText: String

  init(_ text: String) {
    filterText = text.trimmingCharacters(in: .whitespaces)
  }

  var isFiltering: Bool { !filterText.isEmpty }

  func apply(to workspace: Workspace, collapsing collapsed: Set<Project.ID> = []) -> [Entry] {
    // One pass over the worktrees, not one per project; grouping keeps order.
    let byProject = Dictionary(grouping: workspace.worktrees, by: \.projectID)
    return workspace.projects.compactMap { project in
      let worktrees = byProject[project.id] ?? []
      guard isFiltering else {
        return Entry(project: project, worktrees: worktrees, isExpanded: project.isExpanded)
      }
      let isExpanded = !collapsed.contains(project.id)
      if project.name.foldedContains(filterText) {
        return Entry(project: project, worktrees: worktrees, isExpanded: isExpanded)
      }
      let matching = worktrees.filter { matches($0, in: workspace) }
      return matching.isEmpty
        ? nil : Entry(project: project, worktrees: matching, isExpanded: isExpanded)
    }
  }

  private func matches(_ worktree: Worktree, in workspace: Workspace) -> Bool {
    worktree.name.foldedContains(filterText)
      || workspace.displayName(of: worktree).foldedContains(filterText)
  }
}
