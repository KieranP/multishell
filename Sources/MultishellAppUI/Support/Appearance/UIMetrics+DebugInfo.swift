import Foundation

/// The sizes only Debug Info's strips and tables use.
extension UIMetrics {
  /// A debug strip's name and value column, which its axis row keeps clear; the
  /// memory strip's widest label takes 25.8 ems (DebugStripLabelTests).
  var debugStripLabelWidth: Double { (bodySize * 26).rounded() }
  var debugStripHeight: Double { (bodySize * 4.2).rounded() }
  /// A strip's current value, a step above the body text it is set beside.
  var debugStripValueSize: Double { bodySize + 1 }
  /// The debug tables' number columns, which their headers line up over.
  var debugCountColumnWidth: Double { (bodySize * 5.5).rounded() }
  var debugDurationColumnWidth: Double { (bodySize * 4.8).rounded() }
  /// A memory figure with the bar beside it, and one without.
  var debugMemoryBarColumnWidth: Double { (bodySize * 8.5).rounded() }
  var debugMemoryValueColumnWidth: Double { (bodySize * 5.5).rounded() }
  private var debugMemoryBarWidth: Double { (bodySize * 3.5).rounded() }
  /// Two points at least, so a row holding any memory shows a bar.
  func debugMemoryBarLength(forFraction fraction: Double) -> Double {
    max(2, fraction * debugMemoryBarWidth)
  }
  /// A debug table's side inset, which its title, header and rows share.
  static let debugTableInset: Double = 12
  /// A row's disclosure chevron, before its first column.
  static let debugTableChevronWidth: Double = 10
  /// A debug table row's chevron and a process line's nesting arrow.
  var debugTableGlyphSize: Double { small - 1 }
  static let debugTableColumnSpacing: Double = 8
  /// Where a debug table's first column starts, past the chevron.
  static let debugTableTitleInset =
    debugTableInset + debugTableChevronWidth + debugTableColumnSpacing
  /// Right of each debug strip's chart, which the axis row must match for its
  /// ticks to sit under the slots.
  static let debugChartTrailingInset: Double = 10
}
