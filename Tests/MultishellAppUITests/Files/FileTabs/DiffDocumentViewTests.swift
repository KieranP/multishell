import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// The forced row geometry on the macOS running the suite, through a getter
/// Apple does not document as an override point; see files.md.
@Suite @MainActor
struct DiffDocumentViewTests {
  private static let rowCount = 10_750

  @Test func everyRowSitsWhereItsNumberSaysAfterJumpsStartingAtTheEnd() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: Self.rowCount)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    let geometry = textView.geometry

    #expect(textView.frame.height == geometry.documentHeight(rows: Self.rowCount))
    for target in [Self.rowCount - 1, 0, 5_000, 10_457, 1_234, 9_999, 3, 7_777, 4_321] {
      let range = textView.displayText.range(ofRow: target)
      textView.scrollRangeToVisible(NSRange(range))
      textView.layoutSubtreeIfNeeded()
      let rowRect = NSRect(
        x: 0,
        y: geometry.top(ofRow: target),
        width: 1,
        height: geometry.rowHeight,
      )
      #expect(textView.visibleRect.intersects(rowRect), "row \(target) scrolled to but not shown")
      #expect(textView.misplacedRows == [], "at row \(target)")
    }
  }
}
