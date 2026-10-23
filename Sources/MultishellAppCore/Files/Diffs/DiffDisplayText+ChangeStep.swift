import MultishellCore

/// The file tab bar's arrows: a change is a run of rows other than context, so
/// a split side's padding belongs to the change across from it.
extension DiffDisplayText {
  /// The first row of the change a step lands on, `nil` past the last or before
  /// the first; what it counts from is in Docs/design/files.md.
  public func startOfChange(
    _ direction: CycleDirection,
    stepOriginRow: Int?,
    shownRows: Range<Int>,
  ) -> Int? {
    let stepOriginRowShown = stepOriginRow.flatMap { shownRows.contains($0) ? $0 : nil }
    switch direction {
    case .next:
      let from = stepOriginRowShown.map { $0 + 1 } ?? shownRows.lowerBound
      let index = changeStarts.partitioningIndex { $0 >= from }
      return changeStarts.indices.contains(index) ? changeStarts[index] : nil

    case .previous:
      let before = stepOriginRowShown ?? shownRows.lowerBound
      let index = changeStarts.partitioningIndex { $0 >= before }
      return index > 0 ? changeStarts[index - 1] : nil
    }
  }

  /// The row a step counts from, `nil` for the empty caret a text opens with
  /// at its top while nothing is boxed: a change on row 0 is then the first stop.
  public func stepOriginRow(caret: Range<Int>, hasSteppedChange: Bool) -> Int? {
    caret == 0..<0 && !hasSteppedChange ? nil : row(atOffset: caret.lowerBound)
  }

  public func changeSteps(stepOriginRow: Int?, shownRows: Range<Int>) -> ChangeSteps {
    ChangeSteps(
      hasNext: startOfChange(.next, stepOriginRow: stepOriginRow, shownRows: shownRows) != nil,
      hasPrevious: startOfChange(.previous, stepOriginRow: stepOriginRow, shownRows: shownRows)
        != nil,
    )
  }

  /// The rows of the change holding `row`, `nil` on a context row.
  public func change(containing row: Int) -> Range<Int>? {
    guard lines.indices.contains(row), lines[row].kind != .context else { return nil }
    let start = changeStarts[changeStarts.partitioningIndex { $0 > row } - 1]
    var end = row + 1
    while end < lines.count, lines[end].kind != .context { end += 1 }
    return start..<end
  }
}
