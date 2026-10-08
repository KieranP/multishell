import MultishellAppCore
import MultishellCore
import SwiftUI

/// The colours a split strip stacks, named, so none is told by colour alone.
struct DebugSeriesLegend: View {
  let metric: DebugMetric
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 6) {
      entry(t("debug.legend-app"), theme.debugAppSeriesColor)
      if metric.showsTerminals {
        entry(t("debug.legend-terminals"), theme.debugTerminalsSeriesColor)
      }
      entry(t("debug.legend-children"), theme.debugChildrenSeriesColor)
    }
  }

  private func entry(_ name: String, _ color: Color) -> some View {
    HStack(spacing: 3) {
      RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
      Text(name)
        .font(.system(size: metrics.small))
        .foregroundStyle(theme.textSecondary)
    }
  }
}
