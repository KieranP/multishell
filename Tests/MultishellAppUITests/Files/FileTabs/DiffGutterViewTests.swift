import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffGutterViewTests {
  private static func gutter(_ line: DiffLine, numbering: DiffSide) -> DiffGutterView {
    let gutter = DiffGutterView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    gutter.displayText = DiffDisplayText([line], marksStaging: true)
    gutter.numbering = numbering
    return gutter
  }

  @Test func aSplitsCommittedSideIsAsWideAsHeadsNumbers() {
    let shifted = DiffLine(kind: .context, oldNumber: 10_000, newNumber: 9, text: "x")
    let aligned = DiffLine(kind: .context, oldNumber: 10_000, newNumber: 10_000, text: "x")

    #expect(
      Self.gutter(shifted, numbering: .committed).preferredWidth
        == Self.gutter(aligned, numbering: .committed).preferredWidth
    )
  }

  @Test func aScrollTakesThePlusOffTheRowItWasOn() {
    let (view, window) = DiffDocumentFixture.shown(rows: 200)
    defer { withExtendedLifetime(window) {} }
    view.gutter.hoveredRow = 3

    view.scroll(to: NSPoint(x: 0, y: 100))

    #expect(view.gutter.hoveredRow == nil)
  }

  @Test func thePlusHasAColumnOfItsOwnLeftOfTheWidestNumber() {
    let line = DiffLine(kind: .context, oldNumber: 1042, newNumber: 1042, text: "x")
    let gutter = Self.gutter(line, numbering: .onDisk)
    let digitWidth = ("0" as NSString).size(withAttributes: [.font: gutter.geometry.font]).width
    let numberAndSignsWidth: CGFloat = 4 * digitWidth + 12 + 3 + 6

    #expect(gutter.preferredWidth >= gutter.geometry.rowHeight + numberAndSignsWidth)
  }

  @Test func newTextEndsADragAndThePlusOnTheOldRows() {
    let gutter = DiffGutterView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    gutter.hoveredRow = 4
    gutter.draggedRows = (3, 5)

    gutter.displayText = DiffDisplayText(
      [DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "x")],
      marksStaging: true,
    )

    #expect(gutter.draggedRows == nil)
    #expect(gutter.hoveredRow == nil)
  }
}
