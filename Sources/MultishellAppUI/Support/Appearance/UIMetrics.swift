import Foundation

/// Every chrome size, derived from one number so the UI font slider scales
/// the sidebar, tabs and header together and rows never clip their text.
struct UIMetrics: Equatable {
  /// Round a board column and a Debug Info block, which sit on the same fill.
  static let columnCornerRadius: Double = 8

  /// Layout space a split's divider takes, wider than its line: the panes are
  /// NSViews and take mouse events before a SwiftUI overlay.
  static let splitDividerThickness: Double = 6
  static let splitLineThickness: Double = 1
  static let hairlineThickness: Double = 0.5
  /// The least a split gives one pane, read by the layout and by the drop
  /// that would make a group.
  static let minimumPaneLength: Double = 80

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

  /// A state dot inside a line of text: the agents row's lanes, a worker's.
  static let inlineStateDotDiameter: Double = 6
  /// Commands, paths and logs where the text does not follow the UI font:
  /// the settings windows and a worktree's operation pane.
  static let unscaledMonospacedSize: Double = 11
  /// The square a settings row's small glyph button takes: copy, and (i).
  static let settingsGlyphButtonSide: Double = 20

  /// Both settings windows, fixed, or a window would resize between tabs. 600
  /// is the tallest page plus slack; ViewSettingsWindowTests holds it.
  static let settingsWindowSize = CGSize(width: 560, height: 600)

  let bodySize: Double

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

  init(fontSize: Double) {
    bodySize = fontSize
  }

  /// The square a project's glyph is drawn in, which the row's spinner and
  /// state dot take over so nothing shifts.
  static func projectIconSlot(forGlyphOf size: Double) -> Double { size + 6 }

  /// The badge on a glyph's corner, a pane's state or a missing project's
  /// mark: 0.6 of the glyph in whole points, and never below a legible seven.
  static func cornerBadgeSize(onGlyphOf size: Double) -> Double {
    max(7, (size * 0.6).rounded())
  }
}
