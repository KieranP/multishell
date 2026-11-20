import AppKit
import MultishellAppCore

/// The All changes tab's rows between rows: file headers, folds and notices.
extension UIMetrics {
  /// Each file's box, and the sticky header's top, which stands in for one.
  static let allChangesBoxCornerRadius: Double = 6

  /// Above each file's header, setting one file's box apart from the last.
  static let allChangesFileGap: Double = 10
  static let allChangesHeaderSpacing: Double = 8
  /// The hit square of a header's chevron and open button, and the bar's
  /// collapse-all button.
  static let allChangesGlyphButtonSide: Double = 24
  /// Before the chevron's square and after the open button's, setting each
  /// glyph's centre where the mockups did.
  static let allChangesHeaderLeadingInset: Double = 2
  static let allChangesHeaderTrailingInset: Double = 6
  /// Between each file's box and the tab's edges, as the mockups set it apart.
  static let allChangesBoxMargin: Double = 12
  /// Right of the boxes, where the vertical scroller sits: as wide as it grows
  /// under the pointer, or it covers the box's edge.
  @MainActor static var allChangesScrollerMargin: Double {
    let scroller = NSScroller.scrollerWidth(
      for: .regular,
      scrollerStyle: NSScroller.preferredScrollerStyle,
    )
    return max(allChangesBoxMargin, Double(scroller))
  }
  static let allChangesLetterCornerRadius: Double = 4

  /// The square behind a header's M, A or D: 16 pt at the default 13 pt text.
  var allChangesLetterSide: Double { bodySize + 3 }
  /// The open button's and the collapse-all button's drawn glyph: 15 pt at the
  /// default 13 pt text, as the mockups drew them.
  var allChangesGlyphSide: Double { bodySize + 2 }
  var allChangesGlyphLineWidth: Double { allChangesGlyphSide * 1.5 / GlyphGrid.side }

  /// One line of the UI's text with room either side.
  private var allChangesFoldHeight: Double { (bodySize * 2).rounded() }
  private var allChangesNoticeHeight: Double { (bodySize * 3).rounded() }

  func allChangesHeight(of kind: AllChangesGapItem.Kind) -> Double {
    switch kind {
    case .fold: allChangesFoldHeight
    case .notice: allChangesNoticeHeight
    }
  }
}
