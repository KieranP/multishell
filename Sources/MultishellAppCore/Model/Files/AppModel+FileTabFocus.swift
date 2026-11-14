import MultishellCore

/// The keyboard and a file or All changes tab. Only a surface reports its own
/// focus to the store, so such a tab's view reports its own here; see
/// tabs-and-groups/tab-strip.md.
extension AppModel {
  /// The reconcile's hand-off: a file or All changes tab in front takes the
  /// keyboard, as the focused pane of a terminal tab does.
  func requestFocusForFileTabInView() {
    switch workspaceTabInView {
    case .file(let tab): fileTabFocusRequest = tab.id
    case .allChanges(let tab): fileTabFocusRequest = tab.id
    case .terminal, nil: return
    }
  }

  /// The view's, once on screen: `true` once per hand-off, and the view
  /// makes itself first responder on a `true`.
  public func takeFileTabFocusRequest(_ id: FileTab.ID) -> Bool {
    guard fileTabFocusRequest == id else { return false }
    fileTabFocusRequest = nil
    return true
  }

  /// A click into a file or All changes tab: its tab and group take the focus,
  /// so Cmd+W and the menus act there and not on the group the keyboard was in.
  public func noteFileTabFocused(_ id: WorkspaceTab.ID) {
    guard let tab = workspace.workspaceTab(id) else { return }
    if workspace.activeWorkspaceTab(in: tab.worktreeID)?.id != id { store.activateTab(id) }
  }
}
