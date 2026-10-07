import MultishellCore

extension AppModel {
  /// Closing clears the filter, a closed field being unable to say why
  /// rows are missing, and hands the keyboard back rather than dropping it.
  public func setShowsSidebarFilter(_ shows: Bool) {
    showsSidebarFilter = shows
    guard !shows else { return }
    sidebarFilterText = ""
    focusActivePane()
  }

  public func toggleSidebarFilter() {
    setShowsSidebarFilter(!showsSidebarFilter)
  }

  /// Whether the filter has text past its spaces, and so is hiding rows.
  public var isFilteringSidebar: Bool { SidebarFilter(sidebarFilterText).isFiltering }

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
  public func sidebarEmptyMessage(showing entries: [SidebarFilter.Entry]) -> String? {
    if workspace.projects.isEmpty { return t("sidebar.no-projects") }
    return entries.isEmpty ? t("sidebar.nothing-matches") : nil
  }

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

  /// Its rows went unread while collapsed, so they are read now.
  func expandWhileFiltering(_ projectID: Project.ID) {
    guard projectsCollapsedWhileFiltering.remove(projectID) != nil else { return }
    Task { await refreshStatuses(inProject: projectID) }
  }
}
