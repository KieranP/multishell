import MultishellCore

extension AppModel {
  /// The submodules open in the panel, the ones whose own events and status it reads.
  func expandedSubmodules(of id: Worktree.ID) -> [String: SubmoduleReading] {
    let expanded = filesPanelState(of: id).expandedFolders
    return (submoduleReadings[id] ?? [:]).filter { expanded.contains($0.key) }
  }
}
