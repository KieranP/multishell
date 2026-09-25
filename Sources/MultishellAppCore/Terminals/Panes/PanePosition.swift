import MultishellCore

/// Which pane of a split this is, on a board card and a sidebar row alike. A
/// renamed tab gives both its panes one title, so each says which it is.
public struct PanePosition: Equatable, Sendable {
  public let index: Int
  let count: Int

  init(index: Int, count: Int) {
    self.index = index
    self.count = count
  }

  /// The pane at `offset` in `tab`, or `nil` where the tab has only the one.
  public static func of(paneAt offset: Int, in tab: TerminalTab) -> PanePosition? {
    tab.sessionIDs.count > 1 ? PanePosition(index: offset + 1, count: tab.sessionIDs.count) : nil
  }
}
