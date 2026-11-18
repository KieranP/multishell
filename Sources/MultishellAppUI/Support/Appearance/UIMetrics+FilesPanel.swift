/// The Files panel's list, whose rows otherwise take the sidebar's sizes.
extension UIMetrics {
  /// The list's gap to the panel's edges, which its fit adds to the rows and
  /// the filter and scope switch above it keep.
  static let filesPanelListSideInset: Double = 6
  /// Between the filter's well and the button beside it on the Changes page.
  static let filesPanelFilterAccessoryGap: Double = 6
  /// A page's capitals heading, Review's and a services page's sections, letter-spaced.
  static let filesPanelHeadingTracking: Double = 0.4

  /// Between Review's file glyph and the file's name.
  static let reviewFileGlyphSpacing: Double = 6
  /// A comment's lines under its file, so they start where the file's name does.
  var reviewCommentIndent: Double { glyph + Self.reviewFileGlyphSpacing }

  /// An empty page's glyph, a services' page's or Review's, at twice the body size.
  var emptyPageGlyphSide: Double { bodySize * 2 }

  /// Its stroke: a 16-unit glyph's lines at 1.1 units.
  var emptyPageGlyphLineWidth: Double { emptyPageGlyphSide * 1.1 / GlyphGrid.side }
}
