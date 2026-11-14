import AppKit
import MultishellAppCore
import MultishellCore

/// A "Changes" rotor walking the changed lines, forward and back: the text's
/// attributes carry font and colour alone, so nothing else says a line changed.
extension DiffTextView: @MainActor NSAccessibilityCustomRotorItemSearchDelegate {
  override func accessibilityCustomRotors() -> [NSAccessibilityCustomRotor] {
    guard offersChangesRotor else { return [] }
    return [NSAccessibilityCustomRotor(label: t("rotor.changes"), itemSearchDelegate: self)]
  }

  func rotor(
    _ rotor: NSAccessibilityCustomRotor,
    resultFor parameters: NSAccessibilityCustomRotor.SearchParameters,
  ) -> NSAccessibilityCustomRotor.ItemResult? {
    // An item from before the file was emptied would start past the end.
    guard !displayText.lines.isEmpty else { return nil }
    let current = parameters.currentItem.map { displayText.row(atOffset: $0.targetRange.location) }
    let direction: CycleDirection = parameters.searchDirection == .next ? .next : .previous
    return displayText.changedRow(direction, from: current).map(changesRotorItem(atRow:))
  }

  /// The rotor's stop on `row`, read out as the changed line it is.
  func changesRotorItem(atRow row: Int) -> NSAccessibilityCustomRotor.ItemResult {
    let result = NSAccessibilityCustomRotor.ItemResult(targetElement: self)
    result.targetRange = NSRange(displayText.range(ofRow: row))
    result.customLabel = AccessibilityText.changedLine(
      displayText.lines[row],
      marksStaging: displayText.marksStaging,
    )
    return result
  }
}
