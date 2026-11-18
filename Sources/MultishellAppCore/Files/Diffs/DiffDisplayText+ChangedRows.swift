import MultishellCore

/// The changed rows a screen reader's Changes rotor walks.
extension DiffDisplayText {
  /// The changed row after `row`, or before it going back; from `nil`, the
  /// first or the last. `nil` past the last change that way.
  public func changedRow(_ direction: CycleDirection, from row: Int?) -> Int? {
    switch direction {
    case .next:
      let start = min(lines.count, (row ?? -1) + 1)
      return (start..<lines.count).first { lines[$0].isChange }

    case .previous:
      let end = max(0, min(lines.count, row ?? lines.count))
      return (0..<end).last { lines[$0].isChange }
    }
  }
}
