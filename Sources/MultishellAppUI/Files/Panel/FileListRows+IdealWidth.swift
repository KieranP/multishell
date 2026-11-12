import MultishellAppCore
import MultishellCore
import SwiftUI

extension FileListRows {
  /// A text's width varies by its letters, so more rows are laid out than the one
  /// that wins by count; 15,000 listed took 50 ms in a debug build.
  private static let measuredRows = 64

  /// The panel's listed rows for the worktree, at the width that truncates none.
  static func idealWidth(of worktreeID: Worktree.ID, in model: AppModel) -> Double {
    let rows = VStack(spacing: UIMetrics.sidebarRowSpacing) {
      FileListRows(
        model: model,
        worktreeID: worktreeID,
        rows: model.fileTreeRows(of: worktreeID).likeliestWidest(
          measuredRows,
          pendingComments: model.pendingReviewCommentCounts(in: worktreeID),
        ),
        theme: model.currentTheme,
      )
    }
    return ListIdealWidth.of(rows.padding(.horizontal, UIMetrics.filesPanelListSideInset))
  }
}
