import Foundation

/// The sizes only Debug Info's tiles and tables use.
extension UIMetrics {
  /// A debug table's side inset, which its title, header and rows share.
  static let debugTableInset: Double = 12
  /// A row's disclosure chevron, before its first column.
  static let debugTableChevronWidth: Double = 10
  static let debugTableColumnSpacing: Double = 8
  /// A nested row's name past its parent's title, and again for each level below.
  static let debugNestedRowIndent: Double = 14
  /// Where a debug table's first column starts, past the chevron.
  static let debugTableTitleInset =
    debugTableInset + debugTableChevronWidth + debugTableColumnSpacing
  /// Inside each Debug Info tile, and between tiles and between a tile's
  /// label and its chart.
  static let debugTilePadding: Double = 12
  static let debugTileGap: Double = 10

  /// A tile's name, value and caption column; a caption longer than it wraps.
  var debugTileLabelWidth: Double { (bodySize * 18).rounded() }
  /// Narrower than this, a tile's chart goes under its label.
  var debugTileMinimumChartWidth: Double { (bodySize * 10).rounded() }
  var debugTileChartHeight: Double { (bodySize * 3.4).rounded() }
  /// A tile's current value, a step above the body text it is set beside.
  var debugTileValueSize: Double { bodySize + 1 }
  /// The debug tables' number columns, which their headers line up over.
  var debugCountColumnWidth: Double { (bodySize * 5.5).rounded() }
  var debugDurationColumnWidth: Double { (bodySize * 4.8).rounded() }
  /// A memory figure with the bar beside it, and one without.
  var debugMemoryBarColumnWidth: Double { (bodySize * 8.5).rounded() }
  var debugMemoryValueColumnWidth: Double { (bodySize * 5.5).rounded() }
  private var debugMemoryBarWidth: Double { (bodySize * 3.5).rounded() }
  /// A debug table row's chevron and a process line's nesting arrow.
  var debugTableGlyphSize: Double { small - 1 }

  /// Two points at least, so a row holding any memory shows a bar.
  func debugMemoryBarLength(forFraction fraction: Double) -> Double {
    max(2, fraction * debugMemoryBarWidth)
  }
}
