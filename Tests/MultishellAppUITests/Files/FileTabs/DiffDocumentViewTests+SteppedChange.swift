import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

extension DiffDocumentViewTests {
  @Test func aStepBoxesTheChangeItLandedOnUntilTheSelectionMovesOffIt() {
    let (view, window) = DiffDocumentFixture.shown(DiffDocumentFixture.twoChanges)
    defer { withExtendedLifetime(window) {} }

    view.step(toChange: .next)
    let boxed = view.textView.steppedChange
    view.textView.setSelectedRange(
      NSRange(location: DiffDocumentFixture.twoChanges.rowStarts[310], length: 0)
    )

    #expect(boxed == 300..<301)
    #expect(view.textView.steppedChange == nil)
  }

  @Test func aRereadKeepsTheBoxOnTheChangeSteppedTo() {
    let (view, window) = DiffDocumentFixture.shown(DiffDocumentFixture.twoChanges)
    defer { withExtendedLifetime(window) {} }
    view.step(toChange: .next)

    view.show(DiffDocumentFixture.twoChanges, theme: Theme.builtins[0])

    #expect(view.textView.steppedChange == 300..<301)
  }

  @Test func aRebuiltViewBoxesTheChangeItWasLeftOnAndStepsOnFromIt() {
    let first = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var kept: ChangeAnchor?
    first.onSteppedRowsChanged = { rows in
      kept = rows.flatMap(DiffDocumentFixture.twoChanges.anchor(ofChangeAt:))
    }
    first.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let firstWindow = OffscreenWindow.holding(first, deferred: false)
    defer { withExtendedLifetime(firstWindow) {} }
    first.show(DiffDocumentFixture.twoChanges, theme: Theme.builtins[0])
    first.layoutSubtreeIfNeeded()
    first.step(toChange: .next)

    let second = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    if let kept { second.restoreSteppedChangeAnchor(kept) }
    second.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let secondWindow = OffscreenWindow.holding(second, deferred: false)
    defer { withExtendedLifetime(secondWindow) {} }
    second.show(DiffDocumentFixture.twoChanges, theme: Theme.builtins[0])
    second.layoutSubtreeIfNeeded()
    second.scroll(to: NSPoint(x: 0, y: second.textView.geometry.top(ofRow: 290)))
    let boxed = second.textView.steppedChange
    second.step(toChange: .next)

    #expect(boxed == 300..<301)
    #expect(second.textView.steppedChange == 350..<351)
  }

  @Test func aRebuiltViewWhoseBoxedChangeIsGoneLetsGoOfIt() {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [Range<Int>?] = []
    view.onSteppedRowsChanged = { reported.append($0) }
    view.restoreSteppedChangeAnchor(
      ChangeAnchor(
        headDigest: 0,
        headLineAbove: 5,
        headLineBelow: 6,
        textAbove: nil,
        lineText: "nowhere",
      )
    )
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }

    view.show(DiffDocumentFixture.twoChanges, theme: Theme.builtins[0])

    #expect(reported == [nil])
  }

  @Test func aRereadThatEditsTheBoxedLineKeepsTheBoxOnThatChange() {
    func text(editing edited: String) -> DiffDisplayText {
      DiffDisplayText(
        (0..<400).map { row in
          switch row {
          case 0: DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "top")

          case 300: DiffLine(kind: .added, oldNumber: nil, newNumber: 301, text: edited)

          default:
            DiffLine(kind: .context, oldNumber: row, newNumber: row + 1, text: "line \(row)")
          }
        }
      )
    }
    let (view, window) = DiffDocumentFixture.shown(text(editing: "first"))
    defer { withExtendedLifetime(window) {} }
    view.step(toChange: .next)
    view.step(toChange: .next)

    view.show(text(editing: "second"), theme: Theme.builtins[0])

    #expect(view.textView.steppedChange == 300..<301)
  }

  @Test func aRereadLeavesASelectionInsideTheBoxAsItWas() {
    let text = DiffDocumentFixture.text(rows: 400, adding: Set(300..<305))
    let (view, window) = DiffDocumentFixture.shown(text)
    defer { withExtendedLifetime(window) {} }
    view.step(toChange: .next)
    let selected = NSRange(location: text.rowStarts[302] + 1, length: 3)
    view.textView.setSelectedRange(selected)

    view.show(text, theme: Theme.builtins[0])

    #expect(view.textView.selectedRange() == selected)
    #expect(view.textView.steppedChange == 300..<305)
  }
}
