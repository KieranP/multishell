/// What the quick switcher shows, built once a render: its sections and the
/// row the keyboard is on.
public struct QuickSwitcherResults: Equatable, Sendable {
  /// What the rows were listed for.
  public struct Query: Equatable, Sendable {
    let scope: QuickSwitcherScope
    let text: String
  }

  public let sections: [QuickSwitcherSection]
  /// The row last moved to while it is still listed, else the first.
  public let selection: QuickSwitcherTarget?
  /// Why nothing is listed; `nil` where something is.
  public let emptyReason: QuickSwitcherEmptyReason?
  /// Every row's target, top to bottom, for the arrow keys.
  let rows: [QuickSwitcherTarget]
  let query: Query
  /// Counts every arrow press, one that moves nothing at either end included.
  public let arrowPresses: Int
  /// The row last moved to is no longer listed, so the selection is the first;
  /// the model then forgets it, so it is not selected again if it comes back.
  public let isSelectionLost: Bool
  /// The pointer chose the row, which neither scrolls nor is announced.
  let isSelectedByPointer: Bool

  init(
    sections: [QuickSwitcherSection],
    selected: QuickSwitcherTarget?,
    isSelectedByPointer: Bool = false,
    arrowPresses: Int = 0,
    emptyReason: QuickSwitcherEmptyReason? = nil,
    query: Query = Query(scope: .all, text: ""),
  ) {
    self.sections = sections
    self.query = query
    self.arrowPresses = arrowPresses
    let rows = sections.flatMap(\.items).map(\.target)
    self.rows = rows
    let moved = selected.flatMap { rows.contains($0) ? $0 : nil }
    selection = moved ?? rows.first
    isSelectionLost = selected != nil && moved == nil
    self.isSelectedByPointer = isSelectedByPointer
    self.emptyReason = rows.isEmpty ? emptyReason : nil
  }
}
