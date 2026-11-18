import MultishellAppCore
import MultishellCore
import SwiftUI

/// The colours a split tile stacks, named, so none is told by colour alone.
/// One run of text, so a legend wider than the label wraps between entries.
struct DebugSeriesLegend: View {
  private static let nonBreakingSpace = "\u{00A0}"

  let series: [DebugSeries]
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Text(legend)
      .font(metrics.font(size: metrics.small))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// Each square held to its name, and a name to itself, so lines break between entries.
  private var legend: AttributedString {
    series.reduce(into: AttributedString()) { text, band in
      if !text.characters.isEmpty { text += AttributedString("   ") }
      var square = AttributedString("■" + Self.nonBreakingSpace)
      square.foregroundColor = theme.debugColor(of: band)
      var name = AttributedString(
        band.title.replacingOccurrences(of: " ", with: Self.nonBreakingSpace)
      )
      name.foregroundColor = theme.debugInfo.textSecondary
      text += square + name
    }
  }
}
