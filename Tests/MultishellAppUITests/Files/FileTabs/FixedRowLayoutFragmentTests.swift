import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct FixedRowLayoutFragmentTests {
  private static func misplacedRows(in textView: DiffTextView) -> [String] {
    guard let layoutManager = textView.textLayoutManager,
      let viewport = layoutManager.textViewportLayoutController.viewportRange
    else { return ["no viewport"] }
    layoutManager.ensureLayout(for: viewport)
    var misplaced: [String] = []
    layoutManager.enumerateTextLayoutFragments(from: viewport.location, options: []) { fragment in
      let offset = layoutManager.offset(
        from: layoutManager.documentRange.location,
        to: fragment.rangeInElement.location,
      )
      let row = textView.displayText.row(atOffset: offset)
      let expected = CGFloat(row) * textView.geometry.rowHeight
      if abs(fragment.layoutFragmentFrame.minY - expected) > 0.5 {
        misplaced.append(
          "row \(row) at y \(fragment.layoutFragmentFrame.minY) expected \(expected)"
        )
      }
      return fragment.rangeInElement.location.compare(viewport.endLocation) == .orderedAscending
    }
    return misplaced
  }

  @Test(arguments: [(3, 5, 0), (-3, 5, 0), (3, 205, 200), (-3, 205, 200)])
  func aReReadThatAddsOrRemovesRowsDrawsEachRowWhereItsNumberSays(
    rowsAdded: Int,
    at editRow: Int,
    scrolledTo topRow: Int,
  ) {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    let before = (0..<400).map { "line \($0)" }
    view.show(DiffDocumentFixture.contextLines(before), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    view.scroll(to: NSPoint(x: 0, y: view.textView.geometry.top(ofRow: topRow)))
    view.layoutSubtreeIfNeeded()
    #expect(Self.misplacedRows(in: view.textView) == [])
    var after = before
    if rowsAdded > 0 {
      after.insert(contentsOf: (0..<rowsAdded).map { "new \($0)" }, at: editRow)
    } else {
      after.removeSubrange(editRow..<(editRow - rowsAdded))
    }

    view.show(DiffDocumentFixture.contextLines(after), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    let misplaced = Self.misplacedRows(in: view.textView)
    #expect(misplaced == [], "\(misplaced.prefix(5))")
  }
}
