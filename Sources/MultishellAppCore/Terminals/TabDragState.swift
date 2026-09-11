import Foundation
import MultishellCore

/// What a tab drag is doing, for every column of one worktree at once. Drawn
/// only from targets the pointer leaving reports, a drag having no end event.
public struct TabDragState: Equatable, Sendable {
  /// The tab in the air, which the drop that lands has to name. Read only by
  /// a drop, so a stale one moves nothing.
  public var tabID: TerminalTab.ID?
  /// The tab the pointer is over and which side of it, for the insertion
  /// line a strip draws.
  public var insertion: Insertion?
  /// The column whose terminal area the pointer is over, and what the bands
  /// are drawn from, so they go however the drag ended.
  public var overColumn: TabGroup.ID?
  /// The band the pointer is over, lit while it is.
  public var band: Band?

  public init() {}

  public var isDragging: Bool { tabID != nil }

  /// Whether the drag is over something that would take it, and what a strip
  /// marks the dragged tab from. Cannot outlive the drag.
  public var isEngaged: Bool { insertion != nil || overColumn != nil || band != nil }

  /// Whether this column shows its bands: the pointer is over its terminal
  /// area, or over a band, which sits inside that area.
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
