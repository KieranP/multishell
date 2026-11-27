import AppKit
import MultishellAppCore
import MultishellCore

/// A file in the All changes list hands the list the keys that scroll, so they
/// scroll the list and not the file the list holds whole.
extension DiffTextView {
  /// The rows the window shows of this file, about a page.
  private var rowsInSight: Int {
    max(1, Int(visibleRect.height / geometry.rowHeight))
  }

  override func scrollToBeginningOfDocument(_ sender: Any?) {
    if !listTook(#selector(scrollToBeginningOfDocument(_:)), from: sender) {
      super.scrollToBeginningOfDocument(sender)
    }
  }

  override func scrollToEndOfDocument(_ sender: Any?) {
    if !listTook(#selector(scrollToEndOfDocument(_:)), from: sender) {
      super.scrollToEndOfDocument(sender)
    }
  }

  override func scrollPageDown(_ sender: Any?) {
    if !listTook(#selector(scrollPageDown(_:)), from: sender) { super.scrollPageDown(sender) }
  }

  override func scrollPageUp(_ sender: Any?) {
    if !listTook(#selector(scrollPageUp(_:)), from: sender) { super.scrollPageUp(sender) }
  }

  /// `NSTextView` pages by its own scroller's clip, a whole file in the All
  /// changes list: there the list pages and the caret moves a screen's rows.
  override func pageDown(_ sender: Any?) {
    guard listTook(#selector(pageDown(_:)), from: sender) else {
      super.pageDown(sender)
      return
    }
    moveCaret(byRows: rowsInSight)
  }

  override func pageUp(_ sender: Any?) {
    guard listTook(#selector(pageUp(_:)), from: sender) else {
      super.pageUp(sender)
      return
    }
    moveCaret(byRows: -rowsInSight)
  }

  /// Whether the list scrolled for `action`; outside the list, nothing does.
  func listTook(_ action: Selector, from sender: Any?) -> Bool {
    forwardsScrollsTo?.tryToPerform(action, with: sender) ?? false
  }

  /// Set, not moved: a move would scroll the list to the caret after it paged.
  private func moveCaret(byRows delta: Int) {
    let lastRow = displayText.lines.count - 1
    guard lastRow >= 0 else { return }
    let row = displayText.row(atOffset: selectedRange().location) + delta
    setSelectedRange(
      NSRange(location: displayText.rowStarts[row.clamped(to: 0...lastRow)], length: 0)
    )
  }
}
