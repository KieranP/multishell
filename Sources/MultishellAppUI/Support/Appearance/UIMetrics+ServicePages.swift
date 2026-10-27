import Foundation

/// The sizes of the services' glyphs and the panel's pull request and CI pages.
extension UIMetrics {
  /// Every services page's side margin, so its cards, sections and rows line up.
  static let servicePageSideInset: Double = sidebarListSideInset + 4
  /// Between a card's leading glyph and its title.
  static let serviceCardGlyphSpacing: Double = 8

  /// The status glyph leading a check, job or earlier run.
  var servicePageRowGlyphSize: Double { badge + 1 }
  /// How far a job, and what failed in it, sits inside its workflow's name.
  var servicePageJobIndent: Double { badge + 8 }
  /// A section's or an earlier run's chevron, and a check's Required tag.
  var servicePageMarkSize: Double { small - 1 }
  /// A card's lines under its title, so they start where the title does.
  var serviceCardTextIndent: Double { serviceGlyphSize + Self.serviceCardGlyphSpacing }

  /// A CI status's or a conflict's strokes, the design's 1.6 in 16, never
  /// thinner than a point.
  static func statusGlyphLineWidth(side: Double) -> Double { max(1, side * 1.6 / 16) }
}
