import AppKit
import MultishellAppCore

/// The box around the change the last step landed on: set, mirrored onto a
/// split's other side, and carried by line across re-reads and rebuilds.
extension DiffDocumentView {
  private var caretRow: Int {
    textView.displayText.row(atOffset: textView.selectedRange().location)
  }

  /// Boxes `rows`, or lets go with `nil`, and says so. Boxed before the caret
  /// moves into it, so the move does not let go.
  func setSteppedChange(_ rows: Range<Int>?, selectingItsStart: Bool = false) {
    textView.steppedChange = rows
    onSteppedRowsChanged?(rows)
    guard let rows, selectingItsStart else { return }
    textView.setSelectedRange(
      NSRange(location: textView.displayText.rowStarts[rows.lowerBound], length: 0)
    )
  }

  /// The other side's box, on the same rows of a split; a click here clears it.
  func mirrorSteppedChange(_ rows: Range<Int>?) {
    textView.steppedChange = rows
  }

  /// Where a dropped view of this tab boxed a change.
  func restoreSteppedChangeAnchor(_ anchor: ChangeAnchor) {
    pendingSteppedChangeAnchor = anchor
  }

  /// Taken before a re-read swaps the text, by line: the selection it carries
  /// can land on another change where the boxed line was edited.
  func takeSteppedChangeAnchorToCarry(
    boxedIn oldContent: (any ChangeAnchoring)?
  )
    -> ChangeAnchor?
  {
    defer { pendingSteppedChangeAnchor = nil }
    return pendingSteppedChangeAnchor
      ?? textView.steppedChange.flatMap { oldContent?.anchor(ofChangeAt: $0) }
  }

  /// A caret already in the change keeps its selection; a change gone since is
  /// let go of, or a later one in its place would come back boxed.
  func carrySteppedChange(_ anchor: ChangeAnchor?, into newContent: some ChangeAnchoring) {
    guard let anchor else { return }
    guard let rows = newContent.change(at: anchor) else {
      setSteppedChange(nil)
      return
    }
    setSteppedChange(rows, selectingItsStart: !rows.contains(caretRow))
  }

  /// A click or a find moving the caret off the box lets go of it; a re-read
  /// carries it instead.
  func selectionMoved() {
    if let rows = textView.steppedChange, !textView.isReplacingText, !rows.contains(caretRow) {
      setSteppedChange(nil)
    }
    onStepOriginMoved?()
  }
}
