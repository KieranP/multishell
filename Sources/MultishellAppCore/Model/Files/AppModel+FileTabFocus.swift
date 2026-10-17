import MultishellCore

/// The keyboard and a file tab. Only a surface reports its own focus to the
/// store, so a file tab's view reports its own here; see tabs-and-groups.md.
extension AppModel {
  /// The reconcile's hand-off: a file tab in front takes the keyboard, as the
  /// focused pane of a terminal tab does.
  func requestFocusForFileTabInView() {
    guard case .file(let tab) = workspaceTabInView else { return }
    fileTabFocusRequest = tab.id
  }

  /// The view's, once on screen: `true` once per hand-off, and the view
  /// makes itself first responder on a `true`.
  public func takeFileTabFocusRequest(_ id: FileTab.ID) -> Bool {
    guard fileTabFocusRequest == id else { return false }
    fileTabFocusRequest = nil
    return true
  }

  /// A click into a file tab: its tab and group take the focus, so Cmd+W and
  /// the menus act there and not on the group the keyboard was in before.
  public func noteFileTabFocused(_ id: FileTab.ID) {
    guard let tab = workspace.fileTab(id) else { return }
    if workspace.activeWorkspaceTab(in: tab.worktreeID)?.id != id { store.activateTab(id) }
  }
}
