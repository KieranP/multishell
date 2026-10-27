import MultishellCore

extension AppModel {
  /// The chevron. While the filter has text it collapses the project for that
  /// text alone, as the filter opened it; otherwise it sets the stored flag.
  public func toggleExpansion(of project: Project) {
    guard isFilteringSidebar else {
      setExpanded(!project.isExpanded, for: project)
      return
    }
    guard projectsCollapsedWhileFiltering.contains(project.id) else {
      projectsCollapsedWhileFiltering.insert(project.id)
      return
    }
    expandWhileFiltering(project.id)
  }

  func setExpanded(_ expanded: Bool, for project: Project) {
    store.setExpanded(expanded, forProject: project.id)
    // A collapsed project's rows went unread; opening reads them now, through
    // the poll's own read, which holds git to a few at a time.
    guard expanded else { return }
    Task { await refreshStatuses(inProject: project.id) }
  }

  /// Opens the project holding `worktree`, so its row shows: by the chevron's
  /// flag, or by the filter's own, the filter cleared where its text hides the row.
  func expandProject(holding worktree: Worktree) {
    if isFilteringSidebar {
      let isListed = sidebarEntries.contains { entry in
        entry.worktrees.contains { $0.id == worktree.id }
      }
      guard isListed else {
        sidebarFilterText = ""
        expandProject(holding: worktree)
        return
      }
      expandWhileFiltering(worktree.projectID)
    } else if let project = workspace.project(worktree.projectID), !project.isExpanded {
      setExpanded(true, for: project)
    }
  }

  /// Its rows went unread while collapsed, so they are read now.
  func expandWhileFiltering(_ projectID: Project.ID) {
    guard projectsCollapsedWhileFiltering.remove(projectID) != nil else { return }
    Task { await refreshStatuses(inProject: projectID) }
  }
}
