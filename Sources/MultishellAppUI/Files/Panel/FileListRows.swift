import MultishellAppCore
import MultishellCore
import SwiftUI

/// The Files and Changes lists' rows, lazy in the panel and laid out whole for
/// its edge's fit.
struct FileListRows: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  let rows: [FileTreeRow]
  let theme: Theme

  var body: some View {
    // One pass over the comments for every row; a folder's path names no comment.
    let pendingComments = model.pendingReviewCommentCounts(in: worktreeID)
    ForEach(rows) { row in
      FilesPanelRow(
        model: model,
        worktreeID: worktreeID,
        row: row,
        isSelected: model.isShownFile(row, in: worktreeID),
        pendingComments: pendingComments[row.path] ?? 0,
        theme: theme,
      )
    }
  }
}
