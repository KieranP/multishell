import Foundation

/// Every chrome size, derived from one number so the UI font slider scales
/// the sidebar, tabs and header together and rows never clip their text.
struct UIMetrics {
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

  var tabHeight: Double { (body * 2.6).rounded() }
  /// What a tab is drawn at when the strip has room for it.
  var tabMaxWidth: Double { (body * 14.6).rounded() }
  /// And the least it is ever drawn: below this the icon, title and close
  /// button have nowhere to go. See `TabStripLayout`.
  var tabMinWidth: Double { (body * 7.5).rounded() }
  /// The New Tab button at the end of a strip, which never scrolls away.
  var newTabWidth: Double { (body * 2.6).rounded() }
  /// The arrow at either end of a strip with more tabs that way. Its room is
  /// kept either way, so the tabs do not shift under the pointer.
  var tabArrowWidth: Double { (body * 1.7).rounded() }
  var indent: Double { (body * 2).rounded() }

  /// The narrowest a board column is drawn, below which a card's two split
  /// rows run into themselves. See `AgentBoardLayout`.
  var boardColumnMinWidth: Double { (body * 16).rounded() }
  /// Between two board columns, and round the lot of them, taken off before
  /// a column width is asked for so nothing measures itself.
  var boardGap: Double { (body * 0.8).rounded() }
  var boardPadding: Double { (body * 0.9).rounded() }

  /// How wide a drop band down a column's edge is; see `TabGroupBands`. Wide
  /// enough to aim at without hiding what is under it.
  static let dropBandWidth: Double = 74

  /// The sidebar and detail headers, the one size that does not scale with
  /// the font. Not smaller: a hidden title bar still keeps a 40 pt band.
  static let headerHeight: Double = 40
}
