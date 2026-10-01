import MultishellCore

extension AppModel {
  /// Closing clears the filter, a field folded away being unable to say why
  /// rows are missing, and hands the keyboard back rather than dropping it.
  public func setShowsSidebarFilter(_ open: Bool) {
    showsSidebarFilter = open
    guard !open else { return }
    sidebarFilterText = ""
    focusActivePane()
  }

  /// The projects the sidebar shows, each with its rows and whether they show.
  public var sidebarEntries: [SidebarFilter.Entry] {
    SidebarFilter(sidebarFilterText).apply(to: workspace, folding: projectsFoldedWhileFiltering)
  }

  /// The chevron. While the filter has text it folds the project for that
  /// text alone, as the filter opened it; otherwise it sets the stored flag.
  public func toggleExpansion(of project: Project) {
    guard SidebarFilter(sidebarFilterText).isActive else {
      return setExpanded(!project.isExpanded, for: project)
    }
    guard projectsFoldedWhileFiltering.contains(project.id) else {
      projectsFoldedWhileFiltering.insert(project.id)
      return
    }
    unfoldWhileFiltering(project.id)
  }

  /// Its rows went unread while folded, so they are read now.
  func unfoldWhileFiltering(_ projectID: Project.ID) {
    guard projectsFoldedWhileFiltering.remove(projectID) != nil else { return }
    Task { await refreshStatuses(inProject: projectID) }
  }
}
