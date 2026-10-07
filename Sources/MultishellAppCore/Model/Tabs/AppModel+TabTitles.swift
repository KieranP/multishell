import MultishellCore

extension AppModel {
  /// What the tab strip shows: the user's name, else what the shell last
  /// reported, else the tab's starting title.
  public func title(of tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[tab.focusedSessionID] ?? workspace.title(of: tab)
  }

  /// One pane's, a split holding several: the user's name for the tab, else
  /// what this pane's shell last reported, else its starting title.
  func title(ofPane session: TerminalSession, in tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[session.id] ?? session.displayTitle
  }
}
