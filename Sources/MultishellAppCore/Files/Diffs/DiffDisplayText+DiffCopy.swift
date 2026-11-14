/// What Copy puts on the pasteboard: from a unified file tab, a selection
/// touching a change as `git diff` prints it; see Docs/design/files/file-tabs.md.
extension DiffDisplayText {
  /// `selections` are UTF-16 ranges into `string`, as the view holds it.
  public func diffCopy(selections: [Range<Int>]) -> String {
    let touched = selections.map(rows(touching:))
    guard touched.joined().contains(where: { lines[$0].isChange }) else {
      return selections.map(uncutText(in:)).joined(separator: "\n")
    }
    return diffLines(ofRows: touched.joined())
  }

  /// Each row with its `git diff` marker and a newline, padding left out.
  func diffLines(ofRows rows: some Sequence<Int>) -> String {
    rows.filter { lines[$0].kind != .padding }.map { index in
      let marker =
        switch lines[index].kind {
        case .added: "+"
        case .context, .padding: " "
        case .removed: "-"
        }
      return marker + uncutText(ofRow: index) + "\n"
    }.joined()
  }

  /// What a split side copies: the selected text, its padding rows left out.
  public func plainCopy(selections: [Range<Int>]) -> String {
    selections.map { selection in
      rows(touching: selection).compactMap { row -> String? in
        guard lines[row].kind != .padding else { return nil }
        return uncutText(in: range(ofRow: row).clamped(to: selection))
      }.joined(separator: "\n")
    }.joined(separator: "\n")
  }
}
