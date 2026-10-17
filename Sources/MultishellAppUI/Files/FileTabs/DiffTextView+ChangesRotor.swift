import AppKit
import MultishellAppCore
import MultishellCore

/// A "Changes" rotor walking the changed lines, forward and back: the text's
/// attributes carry font and colour alone, so nothing else says a line changed.
extension DiffTextView: @MainActor NSAccessibilityCustomRotorItemSearchDelegate {
  override func accessibilityCustomRotors() -> [NSAccessibilityCustomRotor] {
    [NSAccessibilityCustomRotor(label: t("rotor.changes"), itemSearchDelegate: self)]
  }

  func rotor(
    _ rotor: NSAccessibilityCustomRotor,
    resultFor parameters: NSAccessibilityCustomRotor.SearchParameters,
  ) -> NSAccessibilityCustomRotor.ItemResult? {
    let lines = displayText.lines
    // An item from before the file was emptied would start past the end.
    guard !lines.isEmpty else { return nil }
    let current = parameters.currentItem.map { displayText.row(atOffset: $0.targetRange.location) }
    let forward = parameters.searchDirection == .next
    let candidates: [Int] =
      forward
      ? Array(((current.map { $0 + 1 }) ?? 0)..<lines.count)
      : Array((0..<(current ?? lines.count)).reversed())
    guard let row = candidates.first(where: { lines[$0].isChange }) else { return nil }
    let range = displayText.range(ofRow: row)
    let result = NSAccessibilityCustomRotor.ItemResult(targetElement: self)
    result.targetRange = NSRange(location: range.lowerBound, length: range.count)
    result.customLabel = AccessibilityText.changedLine(lines[row])
    return result
  }
}
