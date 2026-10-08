import MultishellCore

extension AppModel {
  /// The chevron. While the filter has text it collapses the project for that
  /// text alone, as the filter opened it; otherwise it sets the stored flag.
  public func toggleExpansion(of project: Project) {
    guard isFilteringSidebar else {
      return setExpanded(!project.isExpanded, for: project)
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

  /// Its rows went unread while collapsed, so they are read now.
  func expandWhileFiltering(_ projectID: Project.ID) {
    guard projectsCollapsedWhileFiltering.remove(projectID) != nil else { return }
    Task { await refreshStatuses(inProject: projectID) }
  }
}
