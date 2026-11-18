import MultishellAppCore
import MultishellCore
import SwiftUI

/// Debug Info's colours, from the theme's `debug_info` section; the base
/// themes' blue and yellow stay apart for every colour blindness.
extension Theme {
  var debugAppSeriesColor: Color { color(.seriesApp, in: .debugInfo) }
  var debugTerminalsSeriesColor: Color { color(.seriesTerminals, in: .debugInfo) }
  var debugChildrenSeriesColor: Color { color(.seriesChildren, in: .debugInfo) }
  var debugStallColor: Color { color(.stall, in: .debugInfo) }

  func toneColor(_ tone: DebugValueTone) -> Color {
    switch tone {
    case .normal: debugInfo.text
    case .caution: color(.hitch, in: .debugInfo)
    case .alarm: debugStallColor
    }
  }

  /// A split tile's band: blue for the app's own or a tile's main figure, the paler
  /// blue for the terminals' or a part of it, yellow for children or writes, else grey.
  func debugColor(of series: DebugSeries) -> Color {
    switch series {
    case .app, .mainThread, .diskRead, .otherInterruptWakeups: debugAppSeriesColor
    case .appTerminals, .terminalThreads, .packageIdleWakeups: debugTerminalsSeriesColor
    case .childProcesses, .diskWritten: debugChildrenSeriesColor
    case .otherThreads: debugInfo.textTertiary
    }
  }
}
