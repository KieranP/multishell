import MultishellCore

/// How wide the sidebar may be dragged in a window of a given width.
public enum SidebarWidth {
  static let minimum = 180.0
  /// What the sidebar leaves of the window, so the divider stays in reach.
  static let minimumDetail = 50.0
  /// Where a machine that has never moved the divider starts.
  public static let initial = 248.0

  /// A window too narrow for both minimums keeps the sidebar's.
  public static func range(inWindowOfWidth width: Double) -> ClosedRange<Double> {
    minimum...max(minimum, width - minimumDetail)
  }

  /// Where a drag leaves the sidebar, `start` being its width as the drag
  /// began, held to what the window has room for now.
  public static func dragged(
    from start: Double,
    by translation: Double,
    in range: ClosedRange<Double>,
  ) -> Double {
    (start.clamped(to: range) + translation).clamped(to: range)
  }
}
