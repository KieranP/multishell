import SwiftUI

/// The one place the divider's thickness and a pane's minimum width live,
/// read by the layout and by the drop that would make a column.
enum SplitMetrics {
  /// Layout space the divider occupies, wider than the visible line: the
  /// panes are NSViews and take mouse events before a SwiftUI overlay.
  static let dividerThickness: CGFloat = 6
  static let lineThickness: CGFloat = 1
  static let minimumPane: CGFloat = 80
}
