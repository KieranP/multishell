import MultishellAppCore

/// The All changes tab's rows between rows: file headers, folds and notices.
extension UIMetrics {
  /// Above each file's header, setting one file's box apart from the last.
  static let allChangesFileGap: Double = 10
  /// As tall as a file tab's bar, which the header stands in for.
  static let allChangesHeaderBarHeight: Double = 30
  static let allChangesHeaderSpacing: Double = 8
  /// Between each file's box and the tab's edges, as the mockups set it apart.
  static let allChangesBoxMargin: Double = 12
  /// A fold's glyph, in a column as wide as the gutter's numbers start.
  static let allChangesFoldGlyphColumn: Double = 40

  var allChangesHeaderHeight: Double { Self.allChangesFileGap + Self.allChangesHeaderBarHeight }
  /// One line of the UI's text with room either side.
  var allChangesFoldHeight: Double { (bodySize * 2).rounded() }
  var allChangesNoticeHeight: Double { (bodySize * 3).rounded() }

  func allChangesHeight(of kind: AllChangesGapItem.Kind) -> Double {
    switch kind {
    case .header: allChangesHeaderHeight
    case .fold: allChangesFoldHeight
    case .notice: allChangesNoticeHeight

    // As tall as the file's own rows, which only its view can say.
    case .wholeFile: 0
    }
  }
}
