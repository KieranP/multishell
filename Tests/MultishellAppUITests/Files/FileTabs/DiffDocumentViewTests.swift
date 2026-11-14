import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// The forced row geometry on the macOS running the suite, through a getter
/// Apple does not document as an override point; see files/file-tabs.md.
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

  @Test func everyRowSitsWhereItsNumberSaysWithReviewCardGapsOpen() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: Self.rowCount)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    view.setRowGapsHoldingAnchor(RowGaps([10: 80, 4_999: 120, 10_456: 64]))
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

  @Test func everyRowSitsWhereItsNumberSaysWithAllChangesHeaderAndFoldGapsOpen() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: Self.rowCount)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    var gaps: [Int: CGFloat] = [-1: 40]
    for row in stride(from: 199, to: Self.rowCount, by: 200) { gaps[row] = 40 + 26 }
    view.setRowGapsHoldingAnchor(RowGaps(gaps))
    let geometry = textView.geometry

    #expect(geometry.top(ofRow: 0) == DiffRowGeometry.verticalInset + 40)
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

  @Test func theRowsOnScreenAreInTextKitsViewportWithAGapEverySixRows() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: Self.rowCount)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    var gaps: [Int: CGFloat] = [-1: 40]
    for row in stride(from: 5, to: Self.rowCount, by: 6) { gaps[row] = 40 + 26 }
    view.setRowGapsHoldingAnchor(RowGaps(gaps))
    let geometry = textView.geometry

    for target in [Self.rowCount - 1, 0, 5_000, 10_457, 1_234, 9_999, 3, 7_777, 4_321] {
      textView.scrollRangeToVisible(NSRange(textView.displayText.range(ofRow: target)))
      view.layoutSubtreeIfNeeded()
      textView.layoutSubtreeIfNeeded()
      let rowRect = NSRect(
        x: 0,
        y: geometry.top(ofRow: target),
        width: 1,
        height: geometry.rowHeight,
      )
      #expect(textView.visibleRect.intersects(rowRect), "row \(target) scrolled to but not shown")
      #expect(textView.visibleRowsOutsideTheViewport == nil, "at row \(target)")
      #expect(textView.misplacedRows == [], "at row \(target)")
    }
  }

  @Test func highlightingWhileScrolledDeepAmongDenseGapsLeavesTheRowsOnScreenInTheViewport()
    async throws
  {
    let (view, window) = DiffDocumentFixture.shown(rows: Self.rowCount)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    var gaps: [Int: CGFloat] = [-1: 40]
    for row in stride(from: 5, to: Self.rowCount, by: 6) { gaps[row] = 40 + 26 }
    view.setRowGapsHoldingAnchor(RowGaps(gaps))
    view.scroll(to: NSPoint(x: 0, y: textView.geometry.top(ofRow: 9_000)))
    view.layoutSubtreeIfNeeded()
    let runs = (0..<Self.rowCount).map { row in
      HighlightSpan(range: textView.displayText.range(ofRow: row), role: .keyword)
    }

    _ = await textView.applyHighlights(runs, for: textView.displayText, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    textView.layoutSubtreeIfNeeded()

    #expect(textView.visibleRowsOutsideTheViewport == nil)
  }

  @Test func aGutterIsAsWideAsItsMinimumWhenItsNumbersAreNarrower() {
    let (view, window) = DiffDocumentFixture.shown(rows: 8)
    defer { withExtendedLifetime(window) {} }
    let minimum = view.gutter.preferredWidth + 20

    view.minimumGutterWidth = minimum
    view.layoutSubtreeIfNeeded()

    #expect(view.gutter.frame.width == minimum)
  }

  @Test func theFirstRowsAreLaidOutUnderATallGapAboveTheFirstRow() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: 1_000)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    var gaps: [Int: CGFloat] = [-1: 6 * 66]
    for row in stride(from: 40, to: 1_000, by: 40) { gaps[row] = 66 }
    view.setRowGapsHoldingAnchor(RowGaps(gaps))

    view.scroll(to: NSPoint(x: 0, y: 6 * 66 - 100))
    view.layoutSubtreeIfNeeded()
    textView.layoutSubtreeIfNeeded()

    #expect(textView.visibleRowsOutsideTheViewport == nil)
    #expect(textView.misplacedRows == [])
  }
}
