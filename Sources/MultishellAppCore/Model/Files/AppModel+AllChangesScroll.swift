import MultishellCore

/// An All changes tab's scroll, which outlives the view a hidden tab drops and,
/// saved at quit, the launch; and the file at its top.
extension AppModel {
  public func noteAllChangesScrolled(_ id: AllChangesTab.ID, to scroll: AllChangesScroll) {
    allChangesScrolls[id] = scroll
  }

  public func allChangesScroll(of id: AllChangesTab.ID) -> AllChangesScroll? {
    allChangesScrolls[id] ?? workspace.allChangesTab(id)?.scroll
  }

  /// The view's, as it scrolls: the file at the top of the clip.
  public func noteAllChangesTopFile(_ top: AllChangesTopFile?, in id: AllChangesTab.ID) {
    setIfChanged(\.allChangesTopFiles[id], top)
    setIfChanged(\.allChangesLitPaths[id], top?.path)
  }

  public func allChangesTopFile(of id: AllChangesTab.ID) -> AllChangesTopFile? {
    allChangesTopFiles[id]
  }
}
