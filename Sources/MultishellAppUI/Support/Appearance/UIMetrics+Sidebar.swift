import Foundation
import MultishellAppCore

/// The sizes of the sidebar's rows and the blocks they stack into.
extension UIMetrics {
  static let sidebarRowSpacing: Double = 1
  /// One inset for every sidebar row's sides, so the sort menu stays in the
  /// project row's + column and the trailing badges line up.
  static let sidebarRowSideInset: Double = 8
  /// The list's gap to the sidebar's edges, which the filter field above it
  /// keeps so its background lines up with the rows' selection.
  static let sidebarListSideInset: Double = 8
  /// The gap between a sidebar row's glyph column and its text.
  static let sidebarGlyphGap: Double = 7
  /// The + on a project's row, and the sort menu above it sharing its column.
  static let sidebarRowButtonWidth: Double = 24
  /// The Projects header and the sort menu inside it, and the quick
  /// switcher's section titles.
  static let sectionHeaderHeight: Double = 22

  /// A sidebar row carrying a user's name over its branch. Two lines of
  /// text where `rowHeight` holds one, so the branch is not clipped.
  var customNameRowHeight: Double { (bodySize * 3.2).rounded() }
  /// The column a sidebar row's leading glyph sits in, one width for the
  /// worktree, pane, agents and Hidden rows so their text starts alike past it.
  var sidebarGlyphColumn: Double { paneGlyphSize }

  /// A pane's row under the selected worktree: one line of caption-sized text,
  /// shorter than a worktree's so the panes read as its.
  var paneRowHeight: Double { (bodySize * 1.75).rounded() }

  var worktreeRowIndent: Double { (bodySize * 2).rounded() }
  /// A pane's glyph sits under the worktree's name, one step in from its dot.
  var paneRowIndent: Double { worktreeRowIndent + sidebarGlyphColumn }

  /// How tall a worktree's row is. Asked here, the row and the sidebar's
  /// block height disagreeing putting the drop indicator in the wrong half.
  func worktreeRowHeight(hasCustomName: Bool, isRenaming: Bool) -> Double {
    hasCustomName || isRenaming ? customNameRowHeight : rowHeight
  }

  /// How tall a project's block is, which the drop delegate halves: its row, the
  /// Hidden row, and each worktree's with the pane rows of the one showing them.
  func projectBlockHeight(worktreeRows: [SidebarWorktree], showsHiddenSectionRow: Bool) -> Double {
    let top = showsHiddenSectionRow ? rowHeight * 2 + Self.sidebarRowSpacing : rowHeight
    return worktreeRows.reduce(top) { total, row in
      total + Self.sidebarRowSpacing
        + worktreeRowHeight(hasCustomName: row.hasCustomName, isRenaming: row.isRenaming)
        + Double(row.panes.count) * (paneRowHeight + Self.sidebarRowSpacing)
    }
  }
}
