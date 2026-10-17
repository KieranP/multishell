import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct FixedRowLayoutFragmentTests {
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
    #expect(view.textView.misplacedRows == [])
    var after = before
    if rowsAdded > 0 {
      after.insert(contentsOf: (0..<rowsAdded).map { "new \($0)" }, at: editRow)
    } else {
      after.removeSubrange(editRow..<(editRow - rowsAdded))
    }

    view.show(DiffDocumentFixture.contextLines(after), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    let misplaced = view.textView.misplacedRows
    #expect(misplaced == [], "\(misplaced.prefix(5))")
  }
}
