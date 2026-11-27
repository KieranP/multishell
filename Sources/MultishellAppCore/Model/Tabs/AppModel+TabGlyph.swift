import MultishellCore

extension AppModel {
  /// A split tab's mark wins, its panes being more than one; an action's is
  /// read off the focused pane, as an agent's mark is.
  public func glyph(of tab: TerminalTab) -> TerminalTabGlyph {
    if tab.isSplit { return .split }
    return TerminalTabGlyph(
      paneIsAction: workspace.session(tab.focusedSessionID)?.actionName != nil
    )
  }
}
