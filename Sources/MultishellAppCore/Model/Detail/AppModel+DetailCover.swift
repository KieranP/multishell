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

  /// A reconcile under the cover let go of the tabs in front too; `select`
  /// uncovers without, its own reconcile reading the worktree it goes to.
  func uncoverDetailAndReadItsTabs() {
    uncoverDetail()
    readShownFileTabs()
  }
}
