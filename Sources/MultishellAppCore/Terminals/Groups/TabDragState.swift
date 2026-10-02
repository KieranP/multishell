import MultishellCore

/// What a tab drag is doing, for every group of one worktree at once, drawn
/// from what the drop targets report as the pointer comes and goes.
public struct TabDragState: Equatable, Sendable {
  /// The tab in the air, which the drop that lands has to name.
  public internal(set) var tabID: TerminalTab.ID?
  /// The tab the pointer is over and which side of it, for the insertion
  /// line a strip draws.
  public var insertion: Insertion?
  /// The group whose terminal area the pointer is over, and what the bands
  /// are drawn from, so they go however the drag ended.
  public var hoveredGroupID: TabGroup.ID?
  /// The band the pointer is over, lit while it is.
  public var band: TabGroupBand?
  /// Where the tab sat as the drag began, for a drag nothing takes.
  private(set) var home: Home?

  public var isDragging: Bool { tabID != nil }

  /// Whether the drag is over something that would take it, and what a strip
  /// marks the dragged tab from. Cannot outlive the drag.
  var isEngaged: Bool { insertion != nil || hoveredGroupID != nil || band != nil }

  /// Whether this group shows its bands: the pointer is over its terminal
  /// area, or over a band, which sits inside that area.
  public func showsBands(of group: TabGroup.ID) -> Bool {
    hoveredGroupID == group || band?.groupID == group
  }

  /// Whether the tab in the air is one of this strip's, which moves as the
  /// pointer goes rather than being marked by a line.
  public func isShuffling(within tabIDs: [TerminalTab.ID]) -> Bool {
    guard let tabID else { return false }
    return tabIDs.contains(tabID)
  }

  /// Read from the drop targets rather than the drag beginning, so a tab let
  /// go where no target saw it is not marked for good.
  func isHeldOverTarget(_ id: TerminalTab.ID) -> Bool {
    tabID == id && isEngaged
  }

  /// How a strip draws this tab: marked while held over a target, less so
  /// in its own strip, where it moves as the pointer goes.
  public func look(of id: TerminalTab.ID, isShuffling: Bool) -> TabLook {
    guard isHeldOverTarget(id) else { return .resting }
    return isShuffling ? .shuffling : .lifted
  }

  /// The side of this tab the insertion line goes, `nil` for none.
  public func insertionPlacement(
    on id: TerminalTab.ID, isShuffling: Bool
  ) -> TerminalTab.Placement? {
    guard isDragging, !isShuffling, let insertion, insertion.tabID == id else { return nil }
    return insertion.placement
  }

  mutating func begin(_ id: TerminalTab.ID, home: Home? = nil) {
    self = TabDragState()
    tabID = id
    self.home = home
  }

  /// Every drag ends here: a drop through `AppModel.dropDraggedTab`, one that
  /// moves nothing included, and one no drop took through `endAbandonedTabDrag`.
  mutating func end() {
    self = TabDragState()
  }

  public enum TabLook: Equatable, Sendable {
    case resting
    case shuffling
    case lifted
  }

  /// The tabs either side of the dragged one as the drag began, nearest first.
  /// A shuffle moves only the dragged tab, so the rest still say where it was.
  struct Home: Equatable, Sendable {
    let earlier: [TerminalTab.ID]
    let later: [TerminalTab.ID]
  }

  /// Where a dragged tab would land in a strip: on a tab, and which side.
  public struct Insertion: Equatable, Sendable {
    public let tabID: TerminalTab.ID
    let placement: TerminalTab.Placement

    public init(tabID: TerminalTab.ID, placement: TerminalTab.Placement) {
      self.tabID = tabID
      self.placement = placement
    }
  }
}
