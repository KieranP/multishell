/// The parts of a Svelte block head its grammar leaves in one `svelte_raw_text`, in
/// UTF-16 offsets into it. Brackets, quotes and comments hide what they hold.
enum SvelteBlockHead {
  private static let awaitKeywords = ["then", "catch"].map { Array($0.utf16) }
  private static let patternOpeners = Set("{[".utf16)

  /// `item, i (item.id)`: the pattern, and the key where parentheses close the head.
  /// No pattern ends in a call, so closing parentheses after one are always the key.
  static func eachParameter(_ head: String) -> (pattern: Range<Int>, key: Range<Int>?) {
    let scanned = ScannedBlockHead(head)
    let units = scanned.units
    guard let end = scanned.lastNonWhitespace(before: units.count),
      units[end] == JavaScriptUnits.closeParenthesis,
      let open = scanned.openingParenthesisByClosing[end], scanned.bracketDepths[open] == 0,
      scanned.lastNonWhitespace(before: open) != nil
    else { return (units.indices, nil) }
    return (0..<open, open..<end + 1)
  }

  /// `load() then value`: the promise, its `then` or `catch`, and the pattern after it.
  /// `then` is a legal name too; Docs/design/files.md says where it is the keyword.
  static func awaitHead(
    _ head: String
  ) -> (promise: Range<Int>, keyword: Range<Int>?, pattern: Range<Int>?) {
    let scanned = ScannedBlockHead(head)
    let units = scanned.units
    for start in units.indices.dropFirst()
    where scanned.bracketDepths[start] == 0 && !JavaScriptUnits.isWordUnit(units[start - 1])
      && JavaScriptUnits.isWordUnit(units[start])
    {
      let end = units[start...].firstIndex { !JavaScriptUnits.isWordUnit($0) } ?? units.count
      guard awaitKeywords.contains(where: { $0.elementsEqual(units[start..<end]) }),
        let before = scanned.lastNonWhitespace(before: start),
        scanned.endsExpression(at: before), keywordEnds(scanned, at: end)
      else { continue }
      let pattern = end..<units.count
      return (
        0..<start, start..<end,
        scanned.firstNonWhitespace(from: end) == nil ? nil : pattern,
      )
    }
    return (units.indices, nil, nil)
  }

  /// At the end of the head, or before a space and a name, `{` or `[`.
  private static func keywordEnds(_ scanned: ScannedBlockHead, at end: Int) -> Bool {
    guard let next = scanned.firstNonWhitespace(from: end) else { return true }
    let unit = scanned.units[next]
    return next > end && (JavaScriptUnits.isWordUnit(unit) || patternOpeners.contains(unit))
  }
}
