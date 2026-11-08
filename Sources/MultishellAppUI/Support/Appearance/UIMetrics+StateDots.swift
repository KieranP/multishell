import Foundation

/// A state dot's design sizes, which the theme's `ui.state_dot_scale` multiplies.
extension UIMetrics {
  /// A dot standing alone: a worktree's, a collapsed project's, a board column's.
  static let stateDotDiameter: Double = 7
  /// A state dot inside a line of text: the agents row's lanes, a pane row's
  /// rail, a worker's, a Failed card's.
  static let inlineStateDotDiameter: Double = 6

  /// What a dot of `designDiameter` draws at under the theme's scale, for the
  /// dot and for anything laid out around it.
  static func scaledDotDiameter(_ designDiameter: Double, by scale: Double) -> Double {
    designDiameter * scale
  }
}
