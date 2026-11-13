import MultishellAppCore
import MultishellCore
import SwiftUI

/// A file's name and count over its comments; a click on the name opens it.
struct ReviewFileGroupView: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  let group: ReviewFileGroup
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    VStack(alignment: .leading, spacing: 0) {
      Button {
        Task { await model.openFileAsTab(group.path, in: worktreeID) }
      } label: {
        HStack(spacing: UIMetrics.reviewFileGlyphSpacing) {
          Image(systemName: "doc")
            .font(metrics.font(size: metrics.small))
            .foregroundStyle(theme.filesPanel.textTertiary)
            .frame(width: metrics.glyph)
            .accessibilityHidden(true)
          Text(group.fileName)
            .foregroundStyle(theme.filesPanel.text)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: 4)
          Text(group.countText)
            .font(metrics.font(size: metrics.caption))
            .foregroundStyle(theme.filesPanel.textTertiary)
        }
        .font(metrics.font(size: metrics.secondary))
        .padding(.horizontal, UIMetrics.panelSideInset)
        .frame(height: metrics.paneRowHeight)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .help(group.path)
      ForEach(group.rows) { row in
        ReviewCommentRow(
          row: row,
          theme: theme,
          metrics: metrics,
          select: { Task { await model.selectReviewComment(row.id, in: worktreeID) } },
          remove: { model.removeReviewComments([row.id], in: worktreeID) },
        )
      }
    }
  }
}
