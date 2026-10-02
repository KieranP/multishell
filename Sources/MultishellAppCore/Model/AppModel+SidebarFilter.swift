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
    sidebarEntries(filteredBy: sidebarFilterText, collapsing: projectsCollapsedWhileFiltering)
  }

  func sidebarEntries(
    filteredBy text: String, collapsing collapsed: Set<Project.ID>
  )
    -> [SidebarFilter.Entry]
  {
    SidebarFilter(text).apply(to: workspace, collapsing: collapsed)
  }

  /// What the list says in place of rows, `nil` while it shows some.
  public func sidebarEmptyMessage(showing shownProjects: [SidebarFilter.Entry]) -> String? {
    if workspace.projects.isEmpty { return t("sidebar.no-projects") }
    return shownProjects.isEmpty ? t("sidebar.nothing-matches") : nil
  }

  /// The chevron. While the filter has text it collapses the project for that
  /// text alone, as the filter opened it; otherwise it sets the stored flag.
  public func toggleExpansion(of project: Project) {
    guard SidebarFilter(sidebarFilterText).isActive else {
      return setExpanded(!project.isExpanded, for: project)
    }
    guard projectsCollapsedWhileFiltering.contains(project.id) else {
      projectsCollapsedWhileFiltering.insert(project.id)
      return
    }
    expandWhileFiltering(project.id)
  }

  /// Its rows went unread while collapsed, so they are read now.
  func expandWhileFiltering(_ projectID: Project.ID) {
    guard projectsCollapsedWhileFiltering.remove(projectID) != nil else { return }
    Task { await refreshStatuses(inProject: projectID) }
  }
}
