import MultishellCore

extension AppModel {
  /// Moves `id` to sit just above or just below `target`.
  public func moveProject(_ id: Project.ID, _ placement: ProjectPlacement, _ target: Project.ID) {
    let projects = workspace.projects
    guard
      let from = projects.firstIndex(where: { $0.id == id }),
      let anchor = projects.firstIndex(where: { $0.id == target }),
      from != anchor
    else { return }
    let destination = placement == .above ? anchor : anchor + 1
    store.moveProject(at: from, to: destination)
  }

  public func beginProjectDrag(_ id: Project.ID) {
    projectDragReleaseWatch?.cancel()
    projectDragReleaseWatch = nil
    draggedProjectID = id
  }

  public func endProjectDrag() {
    projectDragReleaseWatch?.cancel()
    projectDragReleaseWatch = nil
    draggedProjectID = nil
  }

  /// The dragged project's row was recycled off screen, so its session's end
  /// reaches no one and the button's release ends the drag instead.
  public func projectDragSourceLeft(
    _ id: Project.ID, isPressed: @escaping @MainActor () -> Bool
  ) {
    guard draggedProjectID == id else { return }
    projectDragReleaseWatch?.cancel()
    projectDragReleaseWatch = DragRelease.watch(isPressed: isPressed) { [weak self] in
      guard self?.draggedProjectID == id else { return }
      self?.endProjectDrag()
    }
  }
}
