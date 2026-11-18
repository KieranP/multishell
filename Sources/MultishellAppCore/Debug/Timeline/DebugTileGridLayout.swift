/// How Debug Info's tiles fill a width: two to a row where both fit with charts
/// beside labels, else one, its chart under its label where even that cannot.
public struct DebugTileGridLayout: Sendable, Equatable {
  public let columnCount: Int
  public let chartsBesideLabels: Bool

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
      return Self(columnCount: 2, chartsBesideLabels: true)
    }
    return Self(columnCount: 1, chartsBesideLabels: width >= narrowestBesideTile)
  }
}
