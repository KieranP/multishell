import MultishellAppCore
import MultishellCore
import SwiftUI

/// Debug Info's colours, from the theme's own so a user theme recolours
/// them: blue and yellow stay apart for every kind of colour blindness.
extension Theme {
  /// The app's part of a split strip, and the whole of any other.
  var debugAppSeriesColor: Color { ansiRGB(.blue).color }
  /// The terminals' memory, a paler blue for being inside the app's process.
  var debugTerminalsSeriesColor: Color { ansiRGB(.blue).color.opacity(0.45) }
  /// What the app started, stacked above the app's part and its terminals.
  var debugChildrenSeriesColor: Color { ansiRGB(.yellow).color }

  func smoothnessColor(_ level: Smoothness) -> Color {
    switch level {
    case .smooth: textPrimary
    case .hitched: ansiRGB(.yellow).color
    case .stalled: failureColor
    }
  }
}
