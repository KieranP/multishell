import Foundation
import MultishellCore

/// The projects and rows the sidebar lists, narrowed by any filter text. A
/// project matching keeps all its worktrees; matching folds case and accents.
public struct SidebarListing: Sendable {
  public struct Entry: Equatable, Sendable {
    public let project: Project
    public let worktrees: [Worktree]
    /// Those the user hid, listed in a section of their own under the rest.
    /// The filter narrows them as it does the others.
    public let hiddenWorktrees: [Worktree]
    /// What the chevron and the rows show: while the filter has text it holds
    /// every project open, bar those collapsed under it.
    public let isExpanded: Bool
    /// Collapsed by default, and the filter leaves it so, the section's row
    /// counting what the text found inside.
    public let isHiddenSectionExpanded: Bool

    /// The Hidden row is drawn under an expanded project holding hidden rows.
    public var showsHiddenSectionRow: Bool { isExpanded && !hiddenWorktrees.isEmpty }
    /// The hidden rows are drawn under that row.
    public var showsHiddenWorktrees: Bool { showsHiddenSectionRow && isHiddenSectionExpanded }
  }

  private let filterText: String

  var isFiltering: Bool { !filterText.isEmpty }

  init(filterText text: String) {
    filterText = text.trimmingCharacters(in: .whitespaces)
  }

  func entries(
    in workspace: Workspace,
    collapsing collapsed: Set<Project.ID> = [],
    expandingHiddenSectionsOf expandedHiddenSections: Set<Project.ID> = [],
  ) -> [Entry] {
    // One pass over the worktrees, not one per project; grouping keeps order.
    let byProject = Dictionary(grouping: workspace.worktrees, by: \.projectID)
    return workspace.projects.compactMap { project in
      var listed = byProject[project.id] ?? []
      if isFiltering, !project.name.foldedContains(filterText) {
        listed = listed.filter { matches($0, in: workspace) }
        guard !listed.isEmpty else { return nil }
      }
      return Entry(
        project: project,
        worktrees: listed.filter { !workspace.isHidden($0) },
        hiddenWorktrees: listed.filter(workspace.isHidden),
        isExpanded: isFiltering ? !collapsed.contains(project.id) : project.isExpanded,
        isHiddenSectionExpanded: expandedHiddenSections.contains(project.id),
      )
    }
  }

  private func matches(_ worktree: Worktree, in workspace: Workspace) -> Bool {
    worktree.name.foldedContains(filterText)
      || workspace.displayName(of: worktree).foldedContains(filterText)
  }
}
