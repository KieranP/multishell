/// How Debug Info's tiles fill a width: two to a row where both fit with charts
/// beside labels, else one, its chart under its label where even that cannot.
public struct DebugTileGridLayout: Sendable, Equatable {
  let columnCount: Int
  public let showsChartsBesideLabels: Bool

  /// Every metric's tile, cut into the grid's rows.
  public var metricRows: [[DebugMetric]] {
    let metrics = DebugMetric.allCases
    return stride(from: 0, to: metrics.count, by: columnCount).map { start in
      Array(metrics[start..<min(start + columnCount, metrics.count)])
    }
  }

  /// `tilePadding` is each side's; `gap` sits between tiles and between a label and its chart.
  public static func of(
    width: Double,
    labelWidth: Double,
    minimumChartWidth: Double,
    tilePadding: Double,
    gap: Double,
  ) -> Self {
    let narrowestBesideTile = tilePadding * 2 + labelWidth + gap + minimumChartWidth
    if width >= narrowestBesideTile * 2 + gap {
      return Self(columnCount: 2, showsChartsBesideLabels: true)
    }
    return Self(columnCount: 1, showsChartsBesideLabels: width >= narrowestBesideTile)
  }
}
