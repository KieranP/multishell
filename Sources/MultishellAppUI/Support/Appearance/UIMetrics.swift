import AppKit
import SwiftUI

/// Every chrome size, derived from one number so the UI font slider scales
/// the sidebar, tabs and header together and rows never clip their text.
struct UIMetrics: Equatable {
  /// Round a board column, a Debug Info block and a services' page card.
  static let columnCornerRadius: Double = 8
  /// The find bar's and the quick switcher's panel, and the well their field
  /// sits in, a step inside it.
  static let floatingPanelCornerRadius: Double = 10
  static let floatingPanelWellCornerRadius: Double = floatingPanelCornerRadius - 3
  /// Between a detail placeholder's caption and the buttons under it.
  static let placeholderFooterGap: Double = 22
  /// Round a row's selection and hover fill (sidebar, Files panel, quick
  /// switcher), the filter field, a tooltip and a CI failure's excerpt.
  static let rowCornerRadius: Double = 6
  /// Round the square a chrome glyph button lights under the pointer.
  static let glyphButtonCornerRadius: Double = 6

  /// Layout space a split's divider takes, wider than its line: the panes are
  /// NSViews and take mouse events before a SwiftUI overlay.
  static let splitDividerThickness: Double = 6
  static let splitLineThickness: Double = 1
  static let hairlineThickness: Double = 0.5
  /// How wide a drop band down a group's edge is; see `GroupDropBands`. Wide
  /// enough to aim at without hiding what is under it.
  static let dropBandWidth: Double = 74

  /// The sidebar and detail headers, the one size that does not scale with
  /// the font. Not smaller: a hidden title bar still keeps a 40 pt band.
  static let headerHeight: Double = 40
  /// The side inset of the headers and of the strips along a panel's foot, so
  /// their text starts on one line.
  static let panelSideInset: Double = 14
  /// A header's glyph buttons, unscaled with the band they sit in.
  static let headerGlyphSize: Double = 13
  /// The square a header's glyph button or menu takes around that glyph.
  static let headerGlyphButtonSide: Double = 28
  /// Between the segments in a well, a switch's and the file bar's arrows alike.
  static let segmentSpacing: Double = 2

  /// A state dot inside a line of text: the agents row's lanes, a pane row's
  /// rail, a worker's.
  static let inlineStateDotDiameter: Double = 6
  /// Paths, hook scripts and logs that do not follow the UI font: the settings
  /// window, the New Worktree sheet's path and a worktree's operation pane.
  static let unscaledMonospacedSize: Double = 11
  /// The square a settings row's small glyph button takes: copy, and (i).
  static let settingsGlyphButtonSide: Double = 20

  /// The settings window's content, fixed; AppKit's 32 pt title bar band on top
  /// makes the mockup's 640. ViewSettingsWindowTests holds the pages to it.
  static let settingsWindowSize = CGSize(width: 860, height: 608)
  static let settingsSidebarWidth: Double = 214
  /// A settings page's margins and its groups' cards, rows and titles, as
  /// the approved mockup measured them.
  static let settingsPageTopInset: Double = 18
  /// The page's header band as the mockup drew it, reaching up under the
  /// hidden title bar's 32 pt band.
  static let settingsHeaderHeight: Double = 50
  static let settingsHeaderSideInset: Double = 18
  static let settingsHeaderTitleSize: Double = 15
  static let settingsPageSideInset: Double = 20
  static let settingsPageBottomInset: Double = 26
  static let settingsGroupSpacing: Double = 14
  /// A button's, the Same button's and the Global column's text.
  static let settingsControlTextSize: Double = 12
  /// Group titles, captions, footers and the header's caption.
  static let settingsSmallTextSize: Double = 11
  static let settingsGroupTitleInset: Double = 10
  static let settingsCardRadius: Double = 10
  /// Between a group's rows, and under the page's header.
  static let settingsRuleThickness: Double = 1
  /// A pop-up's, a button's and the Same button's corners, and a sidebar row's.
  static let settingsControlRadius: Double = 6
  /// A pop-up's, a button's and the Same button's, so the three in a row match.
  static let settingsControlVerticalInset: Double = 3
  static let settingsRowSideInset: Double = 12
  static let settingsRowMinHeight: Double = 36
  static let settingsRowSpacing: Double = 12
  /// Between the controls on a row's right, a status and its buttons.
  static let settingsControlSpacing: Double = 8
  /// A row's control, a text field at the mockup's width or a menu and its button.
  static let settingsControlMaxWidth: Double = 260
  /// A command or flags field's text, typed as a shell reads it.
  static let settingsMonospacedFieldSize: Double = 12
  static let settingsSwatchSide: Double = 15
  /// A pop-up's title at least this wide, so a short choice is not a stub.
  static let settingsPopUpMinTitleWidth: Double = 80
  static let settingsSidebarInset: Double = 10
  /// The search field's well and the scope card's tile.
  static let settingsSidebarWellRadius: Double = 7
  static let settingsScopeCardRadius: Double = 9
  /// Puts the search field clear of the traffic lights.
  static let settingsSidebarTopInset: Double = 42
  static let settingsSidebarRowSideInset: Double = 8
  static let settingsSidebarRowSpacing: Double = 8
  /// A split page's parts, in line with the pages' titles past their tiles.
  static var settingsPartIndent: Double {
    settingsSidebarRowSideInset + settingsPageTileSide + settingsSidebarRowSpacing
  }
  static let settingsSidebarGlyphSide: Double = 13
  static let settingsSidebarSpacing: Double = 8
  static let settingsPageTileSide: Double = 20
  static let settingsPageTileRadius: Double = 5
  static let settingsScopeTileSide: Double = 28
  static let settingsScopeGlyphSide: Double = 16
  static let settingsScopeCardInset: Double = 8
  /// The search field's and part rows' text, a step under the page rows'.
  static let settingsSidebarControlFontSize: Double = 12.5
  /// The search field's magnifying glass, as far under its text as the Files panel's is.
  static var settingsSearchGlyphSize: Double { settingsSidebarControlFontSize - 3 }
  /// A project's settings table: the Global column, then the Override column,
  /// wide enough for a path field and its button.
  static let settingsGlobalColumnWidth: Double = 140
  static let settingsOverrideColumnWidth: Double = 210
  static let settingsColumnSpacing: Double = 10
  static let newWorktreeSheetWidth: Double = 520

  let bodySize: Double
  /// Settings > Appearance's UI font; `nil` is the system font.
  let fontFamily: String?

  var secondary: Double { bodySize - 1 }
  var caption: Double { bodySize - 2 }
  var badge: Double { bodySize - 3 }
  /// A row's chevron and lock, a worker's glyph, count and time, a pane's number.
  var small: Double { bodySize - 4 }
  var monospaced: Double { bodySize - 1 }
  var glyph: Double { bodySize - 2 }
  /// A pane's glyph, on its sidebar row and on its tab.
  var paneGlyphSize: Double { glyph + 2 }
  /// The same glyph on a board card's location line, sized to the card's text.
  var cardPaneGlyphSize: Double { badge + 4 }
  /// The split glyph beside a pane's number in its position badge.
  var panePositionGlyphSize: Double { badge - 2 }
  /// The chevron between project and worktree on a board card's location line.
  var cardBreadcrumbChevronSize: Double { badge - 3 }

  var rowHeight: Double { (bodySize * 2.15).rounded() }

  /// The find bar's well height, and each of its glyph buttons' side.
  var findControlSize: Double { (bodySize * 2.2).rounded() }

  /// The sidebar's and the Files panel's filter well.
  var filterWellHeight: Double { (bodySize * 1.85).rounded() }

  init(fontSize: Double, fontFamily: String?) {
    bodySize = fontSize
    self.fontFamily = fontFamily
  }

  /// The square a project's glyph is drawn in, which the row's spinner and
  /// state dot take over so nothing shifts.
  static func projectIconSlot(forGlyphOf size: Double) -> Double { size + 6 }

  /// The least of a head-cut path worth drawing, about a dozen characters of
  /// text at `size`: the header's path and a file tab's folder.
  static func readableTailWidth(atSize size: Double) -> Double { size * 8 }

  /// The badge on a glyph's corner, a pane's state or a missing project's
  /// mark: 0.6 of the glyph in whole points, and never below a legible seven.
  static func cornerBadgeSize(onGlyphOf size: Double) -> Double {
    max(7, (size * 0.6).rounded())
  }

  /// Chrome text and its glyphs in the UI font; code and paths keep the system
  /// monospace.
  func font(size: Double, weight: Font.Weight = .regular) -> Font {
    guard let fontFamily else { return .system(size: size, weight: weight) }
    return .custom(fontFamily, fixedSize: size).weight(weight)
  }

  /// The same font for a field AppKit draws, found by family as the setting
  /// names it; one no longer installed falls back to the system's.
  func appKitFont(size: Double) -> NSFont {
    guard let fontFamily else { return .systemFont(ofSize: size) }
    return NSFont.regular(ofFamily: fontFamily, size: size)
      ?? NSFont(name: fontFamily, size: size) ?? .systemFont(ofSize: size)
  }
}
