extension AppModel {
  /// Closing clears the filter, a field folded away being unable to say why
  /// rows are missing, and hands the keyboard back rather than dropping it.
  public func setShowsSidebarFilter(_ open: Bool) {
    showsSidebarFilter = open
    guard !open else { return }
    sidebarFilterText = ""
    focusActivePane()
  }
}
