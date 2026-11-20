import MultishellCore

/// One Changes rotor across the All changes tab's files, each walked by its
/// own view's text; see Docs/design/files/all-changes-tab.md.
extension AllChangesDocument {
  /// The changed line after `start`, or before it going back, in the file of
  /// `start` or the nearest that way showing one; from `nil`, the first or last.
  public func changedRow(
    _ direction: CycleDirection,
    from start: AllChangesFileRow?,
    slice: (Int) -> AllChangesFileSlice?,
  ) -> AllChangesFileRow? {
    let step = direction == .next ? 1 : -1
    var section = start?.section ?? (direction == .next ? 0 : sections.count - 1)
    var row = start?.row
    while sections.indices.contains(section) {
      if let found = slice(section)?.changedRow(direction, from: row) {
        return AllChangesFileRow(section: section, row: found)
      }
      section += step
      row = nil
    }
    return nil
  }
}
