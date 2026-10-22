extension ScannedBlockHead {
  private static let keywordsBeforeExpression = [
    "await", "case", "delete", "do", "else", "in", "instanceof", "new", "return", "throw",
    "typeof", "void", "yield",
  ].map { Array($0.utf16) }
  private static let conditionKeywords = ["for", "if", "while", "with"].map { Array($0.utf16) }
  private static let steppers = Set("+-".utf16)

  private static func endsOperand(_ unit: UInt16) -> Bool {
    JavaScriptUnits.isWordUnit(unit) || JavaScriptUnits.closingBrackets.contains(unit)
      || JavaScriptUnits.quotes.contains(unit)
  }

  /// Whether the unit at `index` closes an expression: a string, a regex, a postfix `!`,
  /// `++` or `--` and a generic's `>` do, `return` and an `if (…)` condition do not.
  func endsExpression(at index: Int) -> Bool {
    if bracketDepths[index] == nil { return true }
    let unit = units[index]
    if unit == ASCIIUnits.bang { return index > 0 && Self.endsOperand(units[index - 1]) }
    // `Promise<X[]>` has no space before its `>`, where `a > b` has one.
    if unit == ASCIIUnits.greaterThan {
      return index > 0
        && (Self.endsOperand(units[index - 1]) || units[index - 1] == ASCIIUnits.greaterThan)
    }
    if Self.steppers.contains(unit) {
      return index > 1 && units[index - 1] == unit && Self.endsOperand(units[index - 2])
    }
    if unit == JavaScriptUnits.closeParenthesis { return !closesCondition(at: index) }
    guard JavaScriptUnits.isWordUnit(unit) else { return Self.endsOperand(unit) }
    guard let word = word(endingAt: index) else { return true }
    return !Self.keywordsBeforeExpression.contains { $0.elementsEqual(word) }
  }

  /// Whether the `)` at `index` closes the condition of an `if`, `while`, `for` or `with`.
  private func closesCondition(at index: Int) -> Bool {
    guard let open = openingParenthesisByClosing[index],
      let before = lastNonWhitespace(before: open),
      JavaScriptUnits.isWordUnit(units[before]),
      let word = word(endingAt: before)
    else { return false }
    return Self.conditionKeywords.contains { $0.elementsEqual(word) }
  }

  /// The word ending at `index`; `nil` after a `.`, where `api.new` is a property.
  private func word(endingAt index: Int) -> ArraySlice<UInt16>? {
    let start = (units[...index].lastIndex { !JavaScriptUnits.isWordUnit($0) } ?? -1) + 1
    if start > 0, units[start - 1] == ASCIIUnits.dot { return nil }
    return units[start...index]
  }
}
