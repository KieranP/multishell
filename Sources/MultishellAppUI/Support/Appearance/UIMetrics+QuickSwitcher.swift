import Foundation

/// The quick switcher's panel and rows.
extension UIMetrics {
  /// Wide enough for a title, its place and a state beside it; a narrower
  /// window shrinks it.
  static let quickSwitcherWidth: Double = 600
  private static let quickSwitcherVisibleRows: Double = 12
  /// A row's text from its edge, which the section titles line up with.
  static let quickSwitcherRowInset: Double = 8
  /// The field's text from its well's edge, and the footer's from the panel's.
  static let quickSwitcherSideInset: Double = 12
  /// Around the list's rows and titles.
  static let quickSwitcherListPadding: Double = 6
  /// Below the panel, which a short window shrinks the list to keep.
  static let quickSwitcherBottomInset: Double = 24

  /// Below the header and the tab strip under it, so the panel covers neither.
  var quickSwitcherTopInset: Double { Self.headerHeight + tabHeight + 12 }
  var quickSwitcherFieldHeight: Double { (bodySize * 3).rounded() }
  /// The typed text and the prompt laid over it, one size for both.
  var quickSwitcherFieldFontSize: Double { bodySize + 2 }
  var quickSwitcherListHeight: Double { rowHeight * Self.quickSwitcherVisibleRows }
  /// A row's glyph column, room for a pane glyph and the badge on its corner.
  var quickSwitcherGlyphColumn: Double { paneGlyphSize + 4 }

  /// The list's rows and section titles laid out in full, so it is no taller
  /// than they are; a scroll view alone takes all it is offered.
  func quickSwitcherListContentHeight(sections: Int, rows: Int) -> Double {
    let gaps = Double(max(sections + rows - 1, 0)) * Self.sidebarRowSpacing
    return Self.quickSwitcherListPadding * 2 + Double(sections) * Self.sectionHeaderHeight
      + Double(rows) * rowHeight + gaps
  }
}
