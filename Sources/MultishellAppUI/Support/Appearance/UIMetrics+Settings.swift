import Foundation

/// The settings window's sizes: its pages, sidebar, rows and controls.
extension UIMetrics {
  /// The square a settings row's small glyph button takes: copy, and (i).
  static let settingsGlyphButtonSide: Double = 20
  /// A disabled control's opacity: the system switch alone barely changes, and
  /// off it reads the same whether it can be turned on or not.
  static let settingsDisabledOpacity: Double = 0.45

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
  /// Above and below a group's row, its rule between; a caption's differ.
  static let settingsRowVerticalInset: Double = 6
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
  /// A Shortcuts row's keys and its recorder, as wide as the mockup's "Same".
  static let settingsShortcutKeysWidth: Double = 76
  static let settingsShortcutKeysSideInset: Double = 8
  /// The Actions page's name column and keys column, the command taking the rest.
  static let settingsActionNameColumnWidth: Double = 130
  static let settingsActionKeysColumnWidth: Double = 120
}
