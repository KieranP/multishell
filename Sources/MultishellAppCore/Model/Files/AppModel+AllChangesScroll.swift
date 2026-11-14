import MultishellCore

/// An All changes tab's scroll, which outlives the view a hidden tab drops and,
/// saved at quit, the launch.
extension AppModel {
  public func noteAllChangesScrolled(_ id: AllChangesTab.ID, to scroll: AllChangesScroll) {
    allChangesScrolls[id] = scroll
  }

  public func allChangesScroll(of id: AllChangesTab.ID) -> AllChangesScroll? {
    allChangesScrolls[id] ?? workspace.allChangesTab(id)?.scroll
  }
}
