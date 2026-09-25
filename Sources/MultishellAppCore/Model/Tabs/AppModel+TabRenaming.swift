import MultishellCore

extension AppModel {
  /// Sets or clears a title without going through the field; `nil` is the
  /// menu's Use Shell Title.
  public func renameTab(_ id: TerminalTab.ID, to title: String?) {
    renamingTabID = nil
    store.setCustomTitle(title, forTab: id)
  }

  /// A double click on a tab: its title swaps for a field.
  public func beginRenamingTab(_ id: TerminalTab.ID) {
    guard workspace.tab(id) != nil else { return }
    renamingTabID = id
  }

  /// The field's Return, or the focus leaving it. Ignored once the edit has
  /// ended, so an Escape is not undone by the commit losing focus triggers.
  public func commitTabRename(of id: TerminalTab.ID, to title: String?) {
    guard renamingTabID == id else { return }
    renamingTabID = nil
    store.setCustomTitle(title, forTab: id)
  }

  /// The field's Escape: the title stays as it was.
  public func cancelRenamingTab() {
    renamingTabID = nil
  }
}
