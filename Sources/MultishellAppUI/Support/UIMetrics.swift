import MultishellAppCore

/// Every chrome size, derived from one number so the UI font slider scales
/// the sidebar, tabs and header together and rows never clip their text.
struct UIMetrics: Equatable {
  let body: Double

  init(fontSize: Double) {
    body = fontSize
  }

  var secondary: Double { body - 1 }
  var caption: Double { body - 2 }
  var badge: Double { body - 3 }
  /// A row's chevron and lock, a worker's glyph, count and time, a pane's number.
  var small: Double { body - 4 }
  var monospaced: Double { body - 1 }
  var icon: Double { body - 2 }

  var rowHeight: Double { (body * 2.15).rounded() }
  /// A sidebar row carrying a user's name over its branch. Two lines of
  /// text where `rowHeight` holds one, so the branch is not clipped.
  var customNameRowHeight: Double { (body * 3.2).rounded() }

  /// How tall a worktree's row is. Asked here, the row and the sidebar's
  /// block height disagreeing putting the drop indicator in the wrong half.
  func worktreeRowHeight(hasCustomName: Bool, isRenaming: Bool) -> Double {
    hasCustomName || isRenaming ? customNameRowHeight : rowHeight
  }
  static let sidebarRowSpacing: Double = 1
  /// A pane's glyph, on its sidebar row and on its tab.
  var paneGlyphSize: Double { icon + 2 }
  /// The column a sidebar row's leading glyph sits in, one width for every
  /// row so the worktree, pane and agents rows line up.
  var sidebarGlyphColumn: Double { paneGlyphSize }
  var sidebarFilterHeight: Double { (body * 1.85).rounded() }
  /// The + on a project's row, and the sort menu above it sharing its column.
  static let sidebarRowButtonWidth: Double = 24
  /// The Projects header, and the sort menu inside it.
  static let sectionHeaderHeight: Double = 22

  /// The square a project's glyph is drawn in, which the row's spinner and
  /// state dot take over so nothing shifts.
  static func projectIconSlot(forGlyphOf size: Double) -> Double { size + 6 }

  /// How tall a project's block is, which the drop delegate halves: its row,
  /// each worktree's, and the pane rows under the one that shows them.
  func projectBlockHeight(worktreeRows: [SidebarWorktree]) -> Double {
    worktreeRows.reduce(rowHeight) { total, row in
      total + Self.sidebarRowSpacing
        + worktreeRowHeight(hasCustomName: row.hasCustomName, isRenaming: row.isRenaming)
        + Double(row.panes.count) * (paneRowHeight + Self.sidebarRowSpacing)
    }
  }

  /// The badge on a glyph's corner, a pane's state or a missing project's
  /// mark: 0.6 of the glyph in whole points, and never below a legible seven.
  static func cornerBadgeSize(onGlyphOf size: Double) -> Double {
    max(7, (size * 0.6).rounded())
  }

  /// A pane's row under the selected worktree: one line of badge-sized text,
  /// shorter than a worktree's so the panes read as its.
  var paneRowHeight: Double { (body * 1.75).rounded() }

  var tabHeight: Double { (body * 2.6).rounded() }
  /// What a tab is drawn at when the strip has room for it.
  var tabMaxWidth: Double { (body * 14.6).rounded() }
  /// The least a tab is ever drawn at: below this the mark, title and close
  /// button have nowhere to go. See `TabStripLayout`.
  var tabMinWidth: Double { (body * 7.8).rounded() }
  /// A split button at the end of a strip, which never scrolls away.
  var splitButtonWidth: Double { (body * 2.6).rounded() }
  /// The chevron after the New Tab menu's plus, small enough to read as a
  /// mark on the plus rather than a second glyph.
  var menuChevron: Double { (icon * 0.6).rounded() }
  var menuChevronGap: Double { 2 }
  /// A split's width plus the chevron, less one gap; the ink either side
  /// differs from its box. See Docs/design/tabs-and-groups.md.
  var newTabMenuWidth: Double { splitButtonWidth + menuChevron - menuChevronGap }
  /// A split glyph's inset, which the menu's plus shares.
  var stripGlyphInset: Double { (splitButtonWidth - icon) / 2 }
  /// The New Tab menu and the two splits. Comes off the strip before a tab
  /// is measured, so nothing measures itself.
  var stripButtonsWidth: Double { newTabMenuWidth + splitButtonWidth * 2 }
  /// The arrow at either end of a strip with more tabs that way. Its room is
  /// kept either way, so the tabs do not shift under the pointer.
  var tabArrowWidth: Double { (body * 1.7).rounded() }
  /// What the strip's fit rules are worked from.
  var tabStrip: TabStripWidths {
    TabStripWidths(
      buttons: stripButtonsWidth, newTabMenu: newTabMenuWidth, arrow: tabArrowWidth,
      minimumTab: tabMinWidth)
  }
  var indent: Double { (body * 2).rounded() }
  /// The find bar's well height, and each of its glyph buttons' side.
  var findControlSize: Double { (body * 2.2).rounded() }

  /// The narrowest a board column is drawn, below which a card's two split
  /// rows run into themselves. See `AgentBoardLayout`.
  var boardColumnMinWidth: Double { (body * 16).rounded() }
  /// Between two board columns. It and `boardPadding` are taken off before
  /// a column width is asked for, so nothing measures itself.
  var boardGap: Double { (body * 0.8).rounded() }
  /// Round the board's columns.
  var boardPadding: Double { (body * 0.9).rounded() }

  /// A debug strip's name and value column, which its axis row keeps clear;
  /// the memory strip's widest label takes 16 ems (DebugStripLabelTests).
  var debugStripLabelWidth: Double { (body * 17).rounded() }
  var debugStripHeight: Double { (body * 4.2).rounded() }
  /// The debug tables' number columns, which their headers line up over.
  var debugCountColumnWidth: Double { (body * 5.5).rounded() }
  /// A memory figure with the bar beside it, and one without.
  var debugMemoryBarColumnWidth: Double { (body * 8.5).rounded() }
  var debugDurationColumnWidth: Double { (body * 4.8).rounded() }
  var debugMemoryValueColumnWidth: Double { (body * 5.5).rounded() }
  var debugMemoryBarWidth: Double { (body * 3.5).rounded() }
  /// A debug table's side inset, which its title, header and rows share.
  static let debugTableInset: Double = 12
  /// A row's disclosure chevron, before its first column.
  static let debugTableChevronWidth: Double = 10
  static let debugTableColumnSpacing: Double = 8
  /// Where a debug table's first column starts, past the chevron.
  static let debugTableTitleInset =
    debugTableInset + debugTableChevronWidth + debugTableColumnSpacing
  /// Right of each debug strip's chart, which the axis row must match for its
  /// ticks to sit under the slots.
  static let debugChartTrailingInset: Double = 10
  /// Round a board column and a debug panel block, which sit on the same fill.
  static let columnCornerRadius: Double = 8

  /// Layout space a split's divider takes, wider than its line: the panes are
  /// NSViews and take mouse events before a SwiftUI overlay.
  static let splitDividerThickness: Double = 6
  static let splitLineThickness: Double = 1
  static let hairlineThickness: Double = 0.5
  /// How far a sidebar row's name is held back until the row is selected.
  static let unselectedRowNameOpacity: Double = 0.85
  /// The least a split gives one pane, read by the layout and by the drop
  /// that would make a group.
  static let minimumPaneLength: Double = 80

  /// How wide a drop band down a group's edge is; see `GroupDropBands`. Wide
  /// enough to aim at without hiding what is under it.
  static let dropBandWidth: Double = 74

  /// The sidebar and detail headers, the one size that does not scale with
  /// the font. Not smaller: a hidden title bar still keeps a 40 pt band.
  static let headerHeight: Double = 40
}
