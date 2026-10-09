import Foundation
import MultishellAppCore

/// The sizes of the sidebar's rows and the blocks they stack into.
extension UIMetrics {
  /// Round a sidebar row's selection and hover fill and the filter field.
  static let rowCornerRadius: Double = 6
  static let sidebarRowSpacing: Double = 1
  /// One inset for every sidebar row's sides, so the sort menu stays in the
  /// project row's + column and the trailing badges line up.
  static let sidebarRowSideInset: Double = 8
  /// The list's gap to the sidebar's edges, which the filter field above it
  /// keeps so its background lines up with the rows' selection.
  static let sidebarListSideInset: Double = 8
  /// The + on a project's row, and the sort menu above it sharing its column.
  static let sidebarRowButtonWidth: Double = 24
  /// The Projects header, and the sort menu inside it.
  static let sectionHeaderHeight: Double = 22

  /// A sidebar row carrying a user's name over its branch. Two lines of
  /// text where `rowHeight` holds one, so the branch is not clipped.
  var customNameRowHeight: Double { (bodySize * 3.2).rounded() }
  /// The column a sidebar row's leading glyph sits in, one width for every
  /// row so the worktree, pane and agents rows line up.
  var sidebarGlyphColumn: Double { paneGlyphSize }
  var sidebarFilterHeight: Double { (bodySize * 1.85).rounded() }

  /// A pane's row under the selected worktree: one line of badge-sized text,
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

  /// How tall a project's block is, which the drop delegate halves: its row,
  /// each worktree's, and the pane rows under the one that shows them.
  func projectBlockHeight(worktreeRows: [SidebarWorktree]) -> Double {
    worktreeRows.reduce(rowHeight) { total, row in
      total + Self.sidebarRowSpacing
        + worktreeRowHeight(hasCustomName: row.hasCustomName, isRenaming: row.isRenaming)
        + Double(row.panes.count) * (paneRowHeight + Self.sidebarRowSpacing)
    }
  }
}
