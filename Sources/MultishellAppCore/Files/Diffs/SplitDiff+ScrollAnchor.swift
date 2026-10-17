import MultishellCore

/// A split's scroll by the line at its top: `HEAD`'s where the left shows a
/// removed line, as Unified lists those first, so a switch back lands there.
extension SplitDiff {
  public func scroll(atRow row: Double, x: Double) -> FileTabScroll {
    let top = Int(row.rounded(.down))
    guard committed.lines.indices.contains(top), committed.lines[top].kind == .removed else {
      return onDisk.scroll(atRow: row, x: x)
    }
    return committed.scroll(atRow: row, x: x)
  }
}
