import MultishellCore

extension AppModel {
  /// The row's glyphs clicked, or its popover closing; a close another row's
  /// popover outlived leaves that one up.
  public func setShowsServicesPopover(_ shows: Bool, of id: Worktree.ID) {
    if shows {
      setIfChanged(\.servicesPopoverWorktreeID, id)
    } else if servicesPopoverWorktreeID == id {
      servicesPopoverWorktreeID = nil
    }
  }

  func closeServicesPopover() {
    setIfChanged(\.servicesPopoverWorktreeID, nil)
  }
}
