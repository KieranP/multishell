import MultishellCore

/// How wide the Files panel may be dragged in a detail area of a given width,
/// from its left edge.
public enum FilesPanelWidth {
  static let minimum = 200.0
  static let maximum = 560.0
  /// Where a machine that has never moved the edge starts, and where a
  /// double-click on it puts it back.
  public static let initial = 280.0

  /// A detail area too narrow keeps the panel's minimum.
  public static func range(inDetailOfWidth width: Double) -> ClosedRange<Double> {
    minimum...max(minimum, min(maximum, width - TabAreaWidth.minimum))
  }

  /// Dragged by its left edge, so a drag to the left widens it.
  public static func dragged(
    from start: Double,
    by translation: Double,
    in range: ClosedRange<Double>,
  ) -> Double {
    (start.clamped(to: range) - translation).clamped(to: range)
  }
}
