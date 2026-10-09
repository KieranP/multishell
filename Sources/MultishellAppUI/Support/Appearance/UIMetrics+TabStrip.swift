import Foundation
import MultishellAppCore

/// The sizes of a group's tab strip: its tabs, buttons and arrows.
extension UIMetrics {
  static let tabSideInset: Double = 10
  static let tabItemGap: Double = 7
  static let menuChevronGap: Double = 2

  var tabHeight: Double { (bodySize * 2.6).rounded() }
  /// What a tab is drawn at when the strip has room for it.
  var tabMaxWidth: Double { (bodySize * 14.6).rounded() }
  /// The square a tab's close button takes around its glyph.
  var tabCloseButtonSide: Double { (bodySize * 1.55).rounded() }
  /// What the active tab draws besides its title: side insets, the mark, the
  /// close button and a gap either side of the title and its spacer.
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
  /// A split's width plus the chevron, less one gap; the ink either side
  /// differs from its box. See Docs/design/tabs-and-groups.md.
  var newTabMenuWidth: Double { splitButtonWidth + menuChevronSize - Self.menuChevronGap }
  /// A split glyph's inset, which the menu's plus shares.
  var stripGlyphInset: Double { (splitButtonWidth - glyph) / 2 }
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
