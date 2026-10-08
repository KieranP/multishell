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
  public var isFilteringSidebar: Bool { SidebarListing(filterText: sidebarFilterText).isFiltering }

  /// The projects the sidebar shows, each with its rows and whether they show.
  public var sidebarEntries: [SidebarListing.Entry] {
    sidebarEntries(filteredBy: sidebarFilterText, collapsing: projectsCollapsedWhileFiltering)
  }

  func sidebarEntries(
    filteredBy text: String, collapsing collapsed: Set<Project.ID>
  )
    -> [SidebarListing.Entry]
  {
    SidebarListing(filterText: text).entries(in: workspace, collapsing: collapsed)
  }

  /// What the list says in place of rows, `nil` while it shows some.
  public func sidebarEmptyMessage(showing entries: [SidebarListing.Entry]) -> String? {
    if workspace.projects.isEmpty { return t("sidebar.no-projects") }
    return entries.isEmpty ? t("sidebar.nothing-matches") : nil
  }
}
