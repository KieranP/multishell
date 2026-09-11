import Foundation

/// The arithmetic behind a divider drag: the two panes trade weight, both
/// staying at or above the minimum where there is room.
public enum SplitMath {
  /// `translation` is the pointer's movement since the drag began and
  /// `available` the length shared. Unchanged where either is invalid.
  public static func transferring(
    _ translation: Double,
    acrossDividerAfter index: Int,
    in weights: [Double],
    available: Double,
    minimumPane: Double
  ) -> [Double] {
    guard index >= 0, index + 1 < weights.count, available > 0 else { return weights }
    let total = weights.reduce(0, +)
    guard total > 0, total.isFinite else { return weights }

    let perPoint = total / available
    let pair = weights[index] + weights[index + 1]
    // Two panes narrower than the minimum would clamp to a negative share,
    // which SwiftUI refuses and which would be saved as the layout.
    let minimum = min(minimumPane * perPoint, pair / 2)

    var first = weights[index] + translation * perPoint
    first = min(max(first, minimum), pair - minimum)

    var updated = weights
    updated[index] = first
    updated[index + 1] = pair - first
    return updated
  }

  /// Whether that length halves and leaves both halves at the minimum. What
  /// a drop making a new column asks before it offers itself.
  public static func canHalve(_ length: Double, minimumPane: Double, divider: Double) -> Bool {
    guard length.isFinite, minimumPane.isFinite, divider.isFinite else { return false }
    return length - divider >= minimumPane * 2
  }
}
