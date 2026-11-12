import AppKit
import Testing

@testable import MultishellAppUI

@Suite
struct DiffRowGeometryTests {
  private let geometry = DiffRowGeometry(fontFamily: nil, fontSize: 12)

  @Test func aRectOutsideTheViewReachesNoRows() {
    #expect(geometry.rows(in: .null, count: 5).isEmpty)
  }

  @Test func aRectTallerThanAnyDocumentReachesEveryRow() {
    let tall = NSRect(x: 0, y: 0, width: 10, height: CGFloat.greatestFiniteMagnitude)

    #expect(geometry.rows(in: tall, count: 5) == 0..<5)
  }

  @Test func aFamilyThisMacHasIsUsedAndOneItLacksFallsBackToTheSystemMonospace() {
    let menlo = DiffRowGeometry(fontFamily: "Menlo", fontSize: 15)
    let missing = DiffRowGeometry(fontFamily: "No Such Family", fontSize: 15)

    #expect(menlo.font.familyName == "Menlo")
    #expect(menlo.font.pointSize == 15)
    #expect(missing.font == NSFont.monospacedSystemFont(ofSize: 15, weight: .regular))
  }

  @Test func aGapMovesEveryRowBelowItDownByItsHeightAndNoneAbove() {
    var gapped = geometry
    gapped.rowGaps = RowGaps([4: 50])

    #expect(gapped.top(ofRow: 4) == geometry.top(ofRow: 4))
    #expect(gapped.gapTop(afterRow: 4) == geometry.top(ofRow: 5))
    #expect(gapped.top(ofRow: 5) == geometry.top(ofRow: 5) + 50)
    #expect(gapped.documentHeight(rows: 10) == geometry.documentHeight(rows: 10) + 50)
  }

  @Test func aScrollOffsetAndTheRowAtTheTopConvertBothWaysAcrossGaps() {
    var gapped = geometry
    gapped.rowGaps = RowGaps([2: 40, 7: 25])

    for row in [0.0, 1.5, 3, 7, 8, 12.25] {
      #expect(gapped.topRow(atScrollOffset: gapped.scrollOffset(puttingAtTop: row)) == row)
    }
  }

  @Test func aPointInAGapBelongsToTheRowAfterIt() {
    var gapped = geometry
    gapped.rowGaps = RowGaps([2: 40])

    let insideGap = gapped.gapTop(afterRow: 2) + 20
    #expect(gapped.topRow(atScrollOffset: insideGap) == 3)
    let rect = NSRect(x: 0, y: insideGap, width: 10, height: 1)
    #expect(gapped.rows(in: rect, count: 10) == 3..<3)
  }

  @Test func theRowsARectReachesSkipAGapInsideIt() {
    var gapped = geometry
    gapped.rowGaps = RowGaps([2: 400])
    let rect = NSRect(
      x: 0,
      y: gapped.top(ofRow: 1),
      width: 10,
      height: gapped.top(ofRow: 4) - gapped.top(ofRow: 1),
    )

    #expect(gapped.rows(in: rect, count: 10) == 1..<4)
  }

  @Test func aStepLeavesItsContextRowsWhereTheClipHasRoomAndFewerWhereItHasNot() {
    let rowHeight = geometry.rowHeight

    #expect(geometry.rowsAboveAChange(inClipOf: 300) == DiffRowGeometry.contextRowsAboveAChange)
    #expect(geometry.rowsAboveAChange(inClipOf: rowHeight * 2.5) == 1)
    #expect(geometry.rowsAboveAChange(inClipOf: rowHeight) == 0)
    #expect(geometry.rowsAboveAChange(inClipOf: 0) == 0)
  }

  @Test func rowsSpanTheGapsBetweenThem() {
    var gapped = geometry
    gapped.rowGaps = RowGaps([2: 40])

    #expect(gapped.height(ofRows: 1..<4) == 3 * geometry.rowHeight + 40)
    #expect(gapped.height(ofRows: 3..<5) == 2 * geometry.rowHeight)
  }

  @Test func aRowNearTheTopUnderATallGapIsStillPutItsRowsBelowTheTop() {
    var gapped = geometry
    gapped.rowGaps = RowGaps([0: 150])

    let offset = gapped.scrollOffset(putting: 2, rowsBelowTop: 3)

    #expect(gapped.top(ofRow: 2) - offset == 3 * geometry.rowHeight + DiffRowGeometry.verticalInset)
  }
}
