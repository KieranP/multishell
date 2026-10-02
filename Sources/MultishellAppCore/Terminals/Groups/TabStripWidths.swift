/// The widths a tab strip is laid out from, and what they decide: whether the
/// splits show and how much room the tabs and arrows get. See tabs-and-groups.md.
public struct TabStripWidths: Equatable, Sendable {
  /// The New Tab menu and the two splits.
  public let buttons: Double
  public let newTabMenu: Double
  /// The arrow at either end of a strip with more tabs that way.
  public let arrow: Double
  public let minimumTab: Double

  public init(buttons: Double, newTabMenu: Double, arrow: Double, minimumTab: Double) {
    self.buttons = buttons
    self.newTabMenu = newTabMenu
    self.arrow = arrow
    self.minimumTab = minimumTab
  }

  /// Splits go only where they cost neither a whole tab nor the arrows; a
  /// lower bar buys them by silent scrolling.
  public func showsSplits(in width: Double) -> Bool {
    width.isFinite && width >= buttons + 2 * arrow + minimumTab
  }

  /// The room a strip of that width leaves its tabs, its buttons taken off.
  public func tabsAvailable(in width: Double) -> Double {
    width - (showsSplits(in: width) ? buttons : newTabMenu)
  }

  /// Each end's gutter in a scrolling strip with that room. None without room
  /// for both and a tab besides, or two arrows draw over the group beside it.
  public func arrowGutter(forAvailable available: Double) -> Double {
    available >= 2 * arrow + minimumTab ? arrow : 0
  }

  /// What a scrolling strip shows of its tabs. Both gutters keep their room
  /// whether an arrow is drawn or not, so this cannot move what decides that.
  public func scrollingViewport(forAvailable available: Double) -> Double {
    available - 2 * arrowGutter(forAvailable: available)
  }
}
