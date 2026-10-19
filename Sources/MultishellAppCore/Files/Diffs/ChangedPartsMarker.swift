/// Marks the words each changed line differs in. A removed run and the added
/// run after it are diffed as one text, so a rewrap's moved words still match.
enum ChangedPartsMarker {
  static func marking(_ lines: [DiffLine]) -> [DiffLine] {
    var marked = lines
    var index = 0
    while index < lines.count {
      guard lines[index].kind == .removed else {
        index += 1
        continue
      }
      let removedStart = index
      while index < lines.count, lines[index].kind == .removed { index += 1 }
      let addedStart = index
      while index < lines.count, lines[index].kind == .added { index += 1 }
      let (removed, added) = (removedStart..<addedStart, addedStart..<index)
      guard !added.isEmpty else { continue }
      let outcome = WordDiff.changedParts(
        from: removed.map { lines[$0].text }.joined(separator: "\n"),
        to: added.map { lines[$0].text }.joined(separator: "\n"),
      )
      switch outcome {
      case .changed(let old, let new):
        mark(old, onto: removed, of: lines, into: &marked)
        mark(new, onto: added, of: lines, into: &marked)

      case .rewritten:
        continue

      case .tooLongToCompare:
        var budget = WordDiff.comparedPairLimit
        for offset in 0..<min(removed.count, added.count) {
          let removedRow = (removed.lowerBound + offset)..<(removed.lowerBound + offset + 1)
          let addedRow = (added.lowerBound + offset)..<(added.lowerBound + offset + 1)
          let outcome = WordDiff.changedParts(
            from: lines[removedRow.lowerBound].text,
            to: lines[addedRow.lowerBound].text,
            pairBudget: &budget,
          )
          if outcome == .tooLongToCompare { break }
          guard case .changed(let old, let new) = outcome else { continue }
          mark(old, onto: removedRow, of: lines, into: &marked)
          mark(new, onto: addedRow, of: lines, into: &marked)
        }
      }
    }
    return marked
  }

  /// `parts`, in text order, of the run's joined text cut onto its lines; a
  /// line changed whole keeps none, its line's tint already saying so.
  private static func mark(
    _ parts: [Range<Int>],
    onto run: Range<Int>,
    of lines: [DiffLine],
    into marked: inout [DiffLine],
  ) {
    var start = 0
    var next = 0
    for row in run {
      let units = Array(lines[row].text.utf16)
      let line = start..<(start + units.count)
      var local: [Range<Int>] = []
      while next < parts.count, parts[next].lowerBound < line.upperBound {
        let clipped = parts[next].clamped(to: line)
        if !clipped.isEmpty {
          local.append(clipped.shifted(by: -start))
        }
        guard parts[next].upperBound <= line.upperBound else { break }
        next += 1
      }
      let markedUnits = local.reduce(0) { total, range in
        total + WordDiff.nonSpaceUnits(units[range])
      }
      if markedUnits > 0, markedUnits < WordDiff.nonSpaceUnits(units[...]) {
        marked[row] = lines[row].marking(changedParts: local)
      }
      start = line.upperBound + 1
    }
  }
}
