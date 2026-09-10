import Foundation

/// The arithmetic behind a divider drag, kept apart from the view so it can
/// be tested: the two panes either side trade weight, and both stay at or
/// above the minimum when there is room for it.
public enum SplitMath {
  /// `translation` is the pointer's movement along the split axis since the
  /// drag began, `available` the length the panes share, in the same units.
  /// Returns `weights` unchanged when the divider or the length is invalid.
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
    // Two panes narrower than the minimum together would otherwise clamp to
    // a negative share, which SwiftUI refuses to lay out and which would be
    // saved as the tab's layout.
    let minimum = min(minimumPane * perPoint, pair / 2)

    var first = weights[index] + translation * perPoint
    first = min(max(first, minimum), pair - minimum)

    var updated = weights
    updated[index] = first
    updated[index + 1] = pair - first
    return updated
  }

  /// Whether something that long can be halved and leave both halves at the
  /// minimum, the divider between them taken out first.
  ///
  /// What a drop that would make a new tab group asks before it offers
  /// itself: two columns too narrow to read is not what the drag meant, and
  /// refusing springs it back where a resize would merely stop moving.
  public static func canHalve(_ length: Double, minimumPane: Double, divider: Double) -> Bool {
    guard length.isFinite, minimumPane.isFinite, divider.isFinite else { return false }
    return length - divider >= minimumPane * 2
  }
}
