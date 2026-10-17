import MultishellAppCore
import MultishellCore
import SwiftUI

/// Debug Info's colours, from the theme's `debug_info` section; the base
/// themes' blue and yellow stay apart for every colour blindness.
extension Theme {
  /// The app's part of a split strip, and the whole of any other.
  var debugAppSeriesColor: Color { color(.seriesApp, in: .debugInfo) }
  /// The terminals' memory, inside the app's process.
  var debugTerminalsSeriesColor: Color { color(.seriesTerminals, in: .debugInfo) }
  /// What the app started, stacked above the app's part and its terminals.
  var debugChildrenSeriesColor: Color { color(.seriesChildren, in: .debugInfo) }
  var debugStallColor: Color { color(.stall, in: .debugInfo) }

  func smoothnessColor(_ level: Smoothness, on palette: AreaPalette) -> Color {
    switch level {
    case .smooth: palette.text
    case .hitched: color(.hitch, in: .debugInfo)
    case .stalled: debugStallColor
    }
  }
}
