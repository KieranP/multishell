import MultishellCore

extension AppModel {
  /// The panes are back in front of the user, and the focused one's Done seen
  /// unless the caller does its own seen-clearing. The PID watch is told.
  func uncoverDetail(markingInViewSeen marksSeen: Bool = true) {
    guard detailCover != nil else { return }
    detailCover = nil
    updatePIDWatch()
    if marksSeen { markInViewSeen() }
  }
}
