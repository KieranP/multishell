/// How wide the sidebar may be dragged in a window of a given width.
public enum SidebarWidth {
  static let minimum = 180.0
  /// What the sidebar leaves of the window, so the divider stays in reach.
  static let minimumDetail = 50.0

  /// A window too narrow for both minimums keeps the sidebar's.
  public static func range(inWindowOfWidth width: Double) -> ClosedRange<Double> {
    minimum...max(minimum, width - minimumDetail)
  }
}
