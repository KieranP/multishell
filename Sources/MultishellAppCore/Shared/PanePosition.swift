import MultishellCore

/// Which pane of a split this is, on a board card and a sidebar row alike. A
/// renamed tab gives both its panes one title, so each says which it is.
public struct PanePosition: Equatable, Sendable {
  public let number: Int
  let count: Int

  /// The pane at `offset` in `tab`, or `nil` where the tab has only the one.
  static func of(paneAt offset: Int, in tab: TerminalTab) -> Self? {
    tab.sessionIDs.count > 1 ? Self(number: offset + 1, count: tab.sessionIDs.count) : nil
  }
}
