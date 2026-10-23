import AppKit
import MultishellAppCore
import MultishellCore

/// The bar's arrows on this side: the step, and which ways another could go.
extension DiffDocumentView {
  var changeSteps: ChangeSteps {
    textView.displayText.changeSteps(stepOriginRow: stepOriginRow, shownRows: shownRows)
  }

  private var stepOriginRow: Int? {
    textView.displayText.stepOriginRow(
      caret: textView.selectedRange().integerRange,
      hasSteppedChange: textView.steppedChange != nil,
    )
  }

  private var shownRows: Range<Int> {
    textView.geometry.rows(in: textView.visibleRect, count: textView.displayText.lines.count)
  }

  /// The change a few rows under the top, boxed, the caret at its first row
  /// so the next step counts from there.
  func step(toChange direction: CycleDirection) {
    let text = textView.displayText
    let geometry = textView.geometry
    guard
      let row = text.startOfChange(direction, stepOriginRow: stepOriginRow, shownRows: shownRows),
      let rows = text.change(containing: row)
    else { return }
    setSteppedChange(rows, selectingItsStart: true)
    let top = Double(row - geometry.rowsAboveAChange(inClipOf: clipHeight))
    scroll(to: NSPoint(x: scrollOrigin.x, y: geometry.scrollOffset(puttingAtTop: top)))
  }
}
