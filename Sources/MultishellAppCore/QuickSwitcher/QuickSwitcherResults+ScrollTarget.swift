extension QuickSwitcherResults {
  /// New text or scope, or the row moved to gone, goes to the top; otherwise
  /// only an arrow scrolls. Up onto a section's first row shows its title too.
  public func scrollTarget(after previous: QuickSwitcherResults) -> QuickSwitcherScrollTarget? {
    if query != previous.query { return .top }
    guard let selection else { return nil }
    if isSelectionLost, !previous.isSelectionLost, !isSelectedByPointer { return .top }
    guard arrowPresses != previous.arrowPresses else { return nil }
    if selection == rows.first { return .top }
    guard let previousIndex = previous.selection.flatMap(rows.firstIndex(of:)),
      let index = rows.firstIndex(of: selection), index < previousIndex,
      let section = sections.first(where: { $0.items.first?.target == selection })
    else { return .row(selection) }
    return .sectionTitle(section.kind)
  }
}
