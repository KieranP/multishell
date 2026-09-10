import Foundation
import MultishellCore

/// What a tab drag is doing, for every column of one worktree at once.
///
/// One value rather than a piece of state per strip: a tab picked up in one
/// column can land in another, or on the band down the edge of another
/// column's terminal area, and each of those has to draw while the strip
/// the tab came from is not the one under the pointer.
///
/// Nothing is drawn from `tabID`, only from the three targets below, each of
/// which the pointer leaving reports. A drag has no "ended" callback and can
/// be released where no target sees it, over a window's chrome or outside it
/// altogether, so a flag set at the start and cleared by a drop would be a
/// highlight left on screen with no drag behind it.
public struct TabDragState: Equatable, Sendable {
  /// The tab in the air, which the drop that lands has to name. Stale after
  /// a drag that ended where nothing saw it, and read only by a drop, so a
  /// stale one moves nothing.
  public var tabID: TerminalTab.ID?
  /// The tab the pointer is over and which side of it, for the insertion
  /// line a strip draws.
  public var insertion: Insertion?
  /// The column whose terminal area the pointer is over. What the bands are
  /// drawn from, so they arrive as the tab reaches a terminal and go when it
  /// leaves, whether it was dropped, cancelled or carried away.
  public var overColumn: TabGroup.ID?
  /// The band the pointer is over, lit while it is.
  public var band: Band?

  public init() {}

  public var isDragging: Bool { tabID != nil }

  /// Whether the drag is over something that would take it. What a strip
  /// marks the dragged tab from: each of the three targets clears when the
  /// pointer leaves it, so the marking cannot outlive the drag the way a
  /// flag set at pick-up would.
  public var isEngaged: Bool { insertion != nil || overColumn != nil || band != nil }

  /// Whether this column shows its bands: the pointer is over its terminal
  /// area, or over one of the bands themselves, which sit inside that area
  /// and take the pointer off it.
  public func showsBands(of group: TabGroup.ID) -> Bool {
    overColumn == group || band?.groupID == group
  }

  public mutating func begin(_ id: TerminalTab.ID) {
    self = TabDragState()
    tabID = id
  }

  /// Every drop path ends here, the ones that moved nothing included.
  public mutating func end() {
    self = TabDragState()
  }

  /// Where a dragged tab would land in a strip: on a tab, and which side.
  public struct Insertion: Equatable, Sendable {
    public let tabID: TerminalTab.ID
    public let placement: TerminalTab.Placement

    public init(tabID: TerminalTab.ID, placement: TerminalTab.Placement) {
      self.tabID = tabID
      self.placement = placement
    }
  }

  /// Where a dragged tab would make a column: beside this one, on this side.
  public struct Band: Equatable, Sendable {
    public let groupID: TabGroup.ID
    public let placement: TerminalTab.Placement

    public init(groupID: TabGroup.ID, placement: TerminalTab.Placement) {
      self.groupID = groupID
      self.placement = placement
    }
  }
}
