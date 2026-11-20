import Testing

@testable import MultishellAppCore

@Suite
struct DebugTileGridLayoutTests {
  private func layout(width: Double) -> DebugTileGridLayout {
    .of(width: width, labelWidth: 200, minimumChartWidth: 120, tilePadding: 10, gap: 10)
  }

  @Test func twoTilesShareARowOnlyWhereBothFitWithTheirChartsBeside() {
    #expect(
      layout(width: 710) == DebugTileGridLayout(columnCount: 2, showsChartsBesideLabels: true)
    )
    #expect(
      layout(width: 709) == DebugTileGridLayout(columnCount: 1, showsChartsBesideLabels: true)
    )
  }

  @Test func aRowTooNarrowForLabelAndChartSideBySidePutsTheChartUnder() {
    #expect(
      layout(width: 350) == DebugTileGridLayout(columnCount: 1, showsChartsBesideLabels: true)
    )
    #expect(
      layout(width: 349) == DebugTileGridLayout(columnCount: 1, showsChartsBesideLabels: false)
    )
  }

  @Test func everyMetricLandsOnceInRowsNoWiderThanTheColumnCount() {
    for columnCount in [1, 2] {
      let rows = DebugTileGridLayout(columnCount: columnCount, showsChartsBesideLabels: true)
        .metricRows

      #expect(rows.flatMap(\.self) == DebugMetric.allCases)
      #expect(rows.allSatisfy { $0.count <= columnCount })
      #expect(rows.dropLast().allSatisfy { $0.count == columnCount })
    }
  }
}
