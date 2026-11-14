import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct AllChangesWholeFileLayerTests {
  @Test func aFilesHeightBeforeItsViewMeasuresIsItsRowsAloneWithoutTheColumnsGapsOrInsets() {
    var columns = DiffRowGeometry(fontFamily: nil, fontSize: 12)
    columns.rowGaps = RowGaps([3: 500, 40: 900])

    let height = AllChangesWholeFileLayer().height(of: "a.txt", rows: 7, geometry: columns)

    #expect(height == 7 * columns.rowHeight)
  }
}
