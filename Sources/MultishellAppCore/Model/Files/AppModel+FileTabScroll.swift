import MultishellCore

/// A file tab's scroll, which outlives the view a hidden tab drops and, saved
/// at quit, the launch.
extension AppModel {
  public func noteFileTabScrolled(_ id: FileTab.ID, to scroll: FileTabScroll) {
    fileTabScrolls[id] = scroll
  }

  public func fileTabScroll(of id: FileTab.ID) -> FileTabScroll? {
    fileTabScrolls[id] ?? workspace.fileTab(id)?.scroll
  }
}
