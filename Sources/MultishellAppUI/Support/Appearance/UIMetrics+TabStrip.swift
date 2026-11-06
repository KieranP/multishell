import Foundation
import MultishellAppCore

/// The sizes of a group's tab strip: its tabs, buttons and arrows.
extension UIMetrics {
  static let tabSideInset: Double = 10
  static let tabItemGap: Double = 7
  static let menuChevronGap: Double = 2
  /// The least a strip button's lit square stands in, clear of the strip's hairlines.
  private static let stripButtonHoverMinimumInset: Double = 2

  var tabHeight: Double { (bodySize * 2.6).rounded() }
  /// What a tab is drawn at when the strip has room for it.
  var tabMaxWidth: Double { (bodySize * 14.6).rounded() }
  /// The square a tab's close button takes around its glyph.
  var tabCloseButtonSide: Double { (bodySize * 1.55).rounded() }
  /// What every tab draws besides its title: side insets, the mark, the close
  /// button's room and a gap either side of the title and its spacer.
  private var tabFixedPartsWidth: Double {
    Self.tabSideInset * 2 + paneGlyphSize + Self.tabItemGap * 3 + tabCloseButtonSide
  }
  /// The least a tab is ever drawn at: below this the mark, title and close
  /// button have nowhere to go. See `TabStripLayout`.
  var tabMinWidth: Double { max((bodySize * 7.8).rounded(), tabFixedPartsWidth + bodySize * 2) }
  /// A split button at the end of a strip, which never scrolls away.
  var splitButtonWidth: Double { (bodySize * 2.6).rounded() }
  /// The chevron after the New Tab menu's plus, small enough to read as a
  /// mark on the plus rather than a second glyph.
  var menuChevronSize: Double { (glyph * 0.6).rounded() }
  /// A split's width plus the gap and the chevron, so the plus and chevron sit
  /// as far from the lit square's sides as a split's glyph. See tabs-and-groups/tab-strip.md.
  var newTabMenuWidth: Double { splitButtonWidth + Self.menuChevronGap + menuChevronSize }
  /// A split glyph's inset, which the menu's plus shares.
  var stripGlyphInset: Double { (splitButtonWidth - glyph) / 2 }
  /// Inside a strip button, so a split's lit square is a header glyph's size where
  /// it fits; the wider plus menu lights a rectangle as tall.
  var stripButtonHoverInset: Double {
    max(Self.stripButtonHoverMinimumInset, (tabHeight - Self.headerGlyphButtonSide) / 2)
  }
  /// The New Tab menu and the two splits. Comes off the strip before a tab
  /// is measured, so nothing measures itself.
  var stripButtonsWidth: Double { newTabMenuWidth + splitButtonWidth * 2 }
  /// The arrow at either end of a strip with more tabs that way. Its room is
  /// kept either way, so the tabs do not shift under the pointer.
  var tabArrowWidth: Double { (bodySize * 1.7).rounded() }
  /// What the strip's fit rules are worked from.
  var tabStripWidths: TabStripWidths {
    TabStripWidths(
      buttons: stripButtonsWidth,
      newTabMenu: newTabMenuWidth,
      arrow: tabArrowWidth,
      minimumTab: tabMinWidth,
    )
  }
}
