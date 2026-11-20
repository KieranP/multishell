import MultishellCore

/// The Changes rotor's rows in one file: in Split a removed line sits on the
/// left beside the right's padding, so either side's change counts.
extension AllChangesFileSlice {
  func changedRow(_ direction: CycleDirection, from row: Int?) -> Int? {
    let onDisk = text.changedRow(direction, from: row)
    guard let committed = committedText?.changedRow(direction, from: row) else { return onDisk }
    guard let onDisk else { return committed }
    return direction == .next ? min(onDisk, committed) : max(onDisk, committed)
  }

  /// Whether `row`'s change is Split's left side's alone.
  public func changeIsCommittedSideOnly(atRow row: Int) -> Bool {
    guard let committedText, !text.lines[row].isChange else { return false }
    return committedText.lines[row].isChange
  }
}
