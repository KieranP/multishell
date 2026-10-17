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

  /// The rows TextKit 2 laid out in the viewport, each against where its
  /// number says it sits.
  private static func misplacedRows(in textView: DiffTextView) -> [Int] {
    guard let layoutManager = textView.textLayoutManager,
      let viewport = layoutManager.textViewportLayoutController.viewportRange
    else { return [-1] }
    layoutManager.ensureLayout(for: viewport)
    var misplaced: [Int] = []
    layoutManager.enumerateTextLayoutFragments(from: viewport.location, options: []) { fragment in
      let offset = layoutManager.offset(
        from: layoutManager.documentRange.location,
        to: fragment.rangeInElement.location,
      )
      let row = textView.displayText.row(atOffset: offset)
      let expected = CGFloat(row) * textView.geometry.rowHeight
      if abs(fragment.layoutFragmentFrame.minY - expected) > 0.5 { misplaced.append(row) }
      return fragment.rangeInElement.location.compare(viewport.endLocation) == .orderedAscending
    }
    return misplaced
  }

  @Test func everyRowSitsWhereItsNumberSaysAfterJumpsStartingAtTheEnd() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: Self.rowCount)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    let geometry = textView.geometry

    #expect(textView.frame.height == geometry.documentHeight(rows: Self.rowCount))
    for target in [Self.rowCount - 1, 0, 5_000, 10_457, 1_234, 9_999, 3, 7_777, 4_321] {
      let range = textView.displayText.range(ofRow: target)
      textView.scrollRangeToVisible(NSRange(location: range.lowerBound, length: range.count))
      textView.layoutSubtreeIfNeeded()
      let rowRect = NSRect(
        x: 0,
        y: geometry.top(ofRow: target),
        width: 1,
        height: geometry.rowHeight,
      )
      #expect(textView.visibleRect.intersects(rowRect), "row \(target) scrolled to but not shown")
      #expect(Self.misplacedRows(in: textView) == [], "at row \(target)")
    }
  }
}
