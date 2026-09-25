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
  var mono: Double { body - 1 }
  var icon: Double { body - 2 }

  var rowHeight: Double { (body * 2.15).rounded() }
  /// A sidebar row carrying a user's name over its branch. Two lines of
  /// text where `rowHeight` holds one, so the branch is not clipped.
  var namedRowHeight: Double { (body * 3.2).rounded() }

  /// How tall a worktree's row is. Asked here, the row and the sidebar's
  /// block height disagreeing putting the drop indicator in the wrong half.
  func worktreeRowHeight(isNamed: Bool, isRenaming: Bool) -> Double {
    isNamed || isRenaming ? namedRowHeight : rowHeight
  }
  /// The gap between the sidebar's rows.
  static let sidebarRowSpacing: Double = 1

  /// How tall a project's block is, which the drop delegate halves: its row,
  /// each worktree's, and the pane rows under the one that shows them.
  func projectBlockHeight(
    worktreeRows: [(isNamed: Bool, isRenaming: Bool, paneCount: Int)]
  ) -> Double {
    worktreeRows.reduce(rowHeight) { total, row in
      total + Self.sidebarRowSpacing
        + worktreeRowHeight(isNamed: row.isNamed, isRenaming: row.isRenaming)
        + Double(row.paneCount) * (paneRowHeight + Self.sidebarRowSpacing)
    }
  }

  /// A pane's row under the selected worktree: one line of badge-sized text,
  /// shorter than a worktree's so the panes read as its.
  var paneRowHeight: Double { (body * 1.75).rounded() }

  var tabHeight: Double { (body * 2.6).rounded() }
  /// What a tab is drawn at when the strip has room for it.
  var tabMaxWidth: Double { (body * 14.6).rounded() }
  /// And the least it is ever drawn: below this the mark, title and close
  /// button have nowhere to go. See `TabStripLayout`.
  var tabMinWidth: Double { (body * 7.8).rounded() }
  /// A split button at the end of a strip, which never scrolls away.
  var splitButtonWidth: Double { (body * 2.6).rounded() }
  /// The chevron after the New Tab menu's plus, small enough to read as a
  /// mark on the plus rather than a second glyph.
  var menuChevron: Double { (icon * 0.6).rounded() }
  var menuChevronGap: Double { 2 }
  /// A split's width plus the chevron, less one gap; the ink either side
  /// differs from its box. See Docs/design/tabs-and-columns.md.
  var newTabMenuWidth: Double { splitButtonWidth + menuChevron - menuChevronGap }
  /// A split glyph's inset, which the menu's plus shares.
  var stripGlyphInset: Double { (splitButtonWidth - icon) / 2 }
  /// The New Tab menu and the two splits. Comes off the strip before a tab
  /// is measured, so nothing measures itself.
  var stripButtonsWidth: Double { newTabMenuWidth + splitButtonWidth * 2 }
  /// Splits go only where they cost neither a whole tab nor the arrows; a
  /// lower bar buys them by silent scrolling. See tabs-and-columns.md.
  func stripShowsSplits(in width: Double) -> Bool {
    width.isFinite && width >= stripButtonsWidth + 2 * tabArrowWidth + tabMinWidth
  }
  /// The room a strip of that width leaves its tabs, its buttons taken off.
  func stripTabRoom(in width: Double) -> Double {
    width - (stripShowsSplits(in: width) ? stripButtonsWidth : newTabMenuWidth)
  }
  /// The arrow at either end of a strip with more tabs that way. Its room is
  /// kept either way, so the tabs do not shift under the pointer.
  var tabArrowWidth: Double { (body * 1.7).rounded() }
  /// Each end's gutter in a scrolling strip with that room. None without room
  /// for both and a tab besides, or two arrows draw over the column beside it.
  func tabArrowGutter(forRoom room: Double) -> Double {
    room >= 2 * tabArrowWidth + tabMinWidth ? tabArrowWidth : 0
  }
  var indent: Double { (body * 2).rounded() }
  /// The find bar's well height, and each of its glyph buttons' side.
  var findControlSize: Double { (body * 2.2).rounded() }

  /// The narrowest a board column is drawn, below which a card's two split
  /// rows run into themselves. See `AgentBoardLayout`.
  var boardColumnMinWidth: Double { (body * 16).rounded() }
  /// Between two board columns, and round the lot of them, taken off before
  /// a column width is asked for so nothing measures itself.
  var boardGap: Double { (body * 0.8).rounded() }
  var boardPadding: Double { (body * 0.9).rounded() }

  /// How wide a drop band down a column's edge is; see `ColumnDropBands`. Wide
  /// enough to aim at without hiding what is under it.
  static let dropBandWidth: Double = 74

  /// The sidebar and detail headers, the one size that does not scale with
  /// the font. Not smaller: a hidden title bar still keeps a 40 pt band.
  static let headerHeight: Double = 40
}
