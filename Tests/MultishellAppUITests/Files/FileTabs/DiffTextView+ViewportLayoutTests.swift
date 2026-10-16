import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffTextViewViewportLayoutTests {
  @Test func aJumpToTheMiddleLaysOutOnlyTheRowsAroundIt() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: 10_750)
    defer { withExtendedLifetime(window) {} }
    let layoutManager = try #require(view.textView.textLayoutManager)

    view.scroll(to: NSPoint(x: 0, y: view.textView.frame.height / 2))
    view.layoutSubtreeIfNeeded()

    var laidOut = 0
    layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location) {
      fragment in
      if fragment.state == .layoutAvailable { laidOut += 1 }
      return true
    }
    #expect(laidOut < 300, "\(laidOut) rows laid out")
    #expect(view.topRow > 5_000, "top row \(view.topRow)")
  }

  @Test func aReReadThatShrinksTheTextUnderTheViewLaysOutNoRowsOfTheOldText() throws {
    let (view, window) = DiffDocumentFixture.shown(
      contextLines: Array(repeating: String(repeating: "x", count: 50), count: 10_000)
    )
    defer { withExtendedLifetime(window) {} }
    let layoutManager = try #require(view.textView.textLayoutManager)
    let rowDelegate = try #require(layoutManager.delegate as? FixedRowLayoutDelegate)
    view.scroll(to: NSPoint(x: 0, y: view.textView.frame.height))
    view.layoutSubtreeIfNeeded()
    let counter = CountingLayoutDelegate(wrapping: rowDelegate)
    layoutManager.delegate = counter
    defer { layoutManager.delegate = rowDelegate }

    let shrunk = DiffDocumentFixture.contextLines(
      Array(repeating: String(repeating: "abcdefgh, ", count: 1_000), count: 30)
    )
    view.show(shrunk, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    #expect(counter.rowsMade <= shrunk.lines.count, "\(counter.rowsMade) rows laid out")
  }
}
