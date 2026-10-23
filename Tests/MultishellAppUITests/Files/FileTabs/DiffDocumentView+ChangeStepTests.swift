import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffDocumentViewChangeStepTests {
  @Test func eachStepDownPutsTheNextChangeUnderAFewRowsOfContextWithTheSelectionAtIt() {
    let (view, window) = DiffDocumentFixture.shown(DiffDocumentFixture.twoChanges)
    defer { withExtendedLifetime(window) {} }

    view.step(toChange: .next)
    let firstTop = view.topRow
    let firstSelection = view.textView.selectedRange()
    view.step(toChange: .next)

    #expect(firstTop == Double(300 - DiffRowGeometry.contextRowsAboveAChange))
    #expect(
      firstSelection == NSRange(location: DiffDocumentFixture.twoChanges.rowStarts[300], length: 0)
    )
    #expect(view.topRow == Double(350 - DiffRowGeometry.contextRowsAboveAChange))
  }

  @Test func aStepUpAfterScrollingPastBothChangesLandsOnTheLower() {
    let (view, window) = DiffDocumentFixture.shown(DiffDocumentFixture.twoChanges)
    defer { withExtendedLifetime(window) {} }
    view.scroll(to: NSPoint(x: 0, y: view.textView.geometry.top(ofRow: 380)))

    view.step(toChange: .previous)

    #expect(view.topRow == Double(350 - DiffRowGeometry.contextRowsAboveAChange))
  }

  @Test func aStepKeepsTheColumnScrolledSidewaysTo() {
    let wide = DiffDisplayText(
      (0..<400).map { row in
        row == 300
          ? DiffLine(kind: .added, oldNumber: nil, newNumber: row + 1, text: "new")
          : DiffLine(
            kind: .context,
            oldNumber: row + 1,
            newNumber: row + 1,
            text: String(repeating: "w", count: 300),
          )
      }
    )
    let (view, window) = DiffDocumentFixture.shown(wide)
    defer { withExtendedLifetime(window) {} }
    view.scroll(to: NSPoint(x: 400, y: 0))

    view.step(toChange: .next)

    #expect(view.scrollOrigin.x == 400)
    #expect(view.topRow == Double(300 - DiffRowGeometry.contextRowsAboveAChange))
  }

  @Test func stepsInAPaneTooShortForTheContextRowsStillMoveOnToTheNextChange() {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 40)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(DiffDocumentFixture.twoChanges, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    view.step(toChange: .next)
    view.step(toChange: .next)

    #expect(
      view.textView.selectedRange()
        == NSRange(location: DiffDocumentFixture.twoChanges.rowStarts[350], length: 0)
    )
  }

  @Test func theViewReportsWhichWayAStepCanGoAsItMoves() {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [ChangeSteps] = []
    view.onStepOriginMoved = { [weak view] in
      if let view { reported.append(view.changeSteps) }
    }
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(DiffDocumentFixture.twoChanges, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    let atTheTop = reported.last

    view.step(toChange: .next)
    view.step(toChange: .next)

    #expect(atTheTop == ChangeSteps(hasNext: true, hasPrevious: false))
    #expect(reported.last == ChangeSteps(hasNext: false, hasPrevious: true))
  }

  @Test func aNewFilesOnlyChangeCanBeSteppedTo() {
    let newFile = DiffDisplayText(
      (0..<40).map { row in
        DiffLine(kind: .added, oldNumber: nil, newNumber: row + 1, text: "line \(row)")
      }
    )
    let (view, window) = DiffDocumentFixture.shown(newFile)
    defer { withExtendedLifetime(window) {} }
    let atOpen = view.changeSteps

    view.step(toChange: .next)

    #expect(atOpen.allows(.next))
    #expect(view.textView.steppedChange == 0..<40)
  }
}
