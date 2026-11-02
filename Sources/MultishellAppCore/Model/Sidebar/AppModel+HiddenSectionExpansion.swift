import MultishellCore

extension AppModel {
  /// The Hidden row's chevron.
  public func toggleHiddenSectionExpansion(of project: Project) {
    if expandedHiddenSections.contains(project.id) {
      expandedHiddenSections.remove(project.id)
    } else {
      expandHiddenSection(of: project.id)
    }
  }

  /// Its rows went unread while it was collapsed, so they are read now.
  func expandHiddenSection(of projectID: Project.ID) {
    guard expandedHiddenSections.insert(projectID).inserted else { return }
    Task { await refreshStatuses { $0.projectID == projectID && self.workspace.isHidden($0) } }
  }
}
