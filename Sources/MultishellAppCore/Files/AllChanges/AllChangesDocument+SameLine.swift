/// Find's selection carried across a relayout of the All changes tab: every file
/// numbers its own lines, so the match stays in its own file, found by path.
extension AllChangesDocument {
  func rangeOnSameLine(_ range: Range<Int>, from previous: AllChangesDocument) -> Range<Int>? {
    let row = previous.text.row(atOffset: range.lowerBound)
    guard let previousIndex = previous.section(atRow: row),
      let index = section(at: previous.sections[previousIndex].path)
    else { return nil }
    return text.rangeOnSameLine(
      range,
      from: previous.text,
      inRows: sections[index].rows,
      fromRows: previous.sections[previousIndex].rows,
    )
  }
}
