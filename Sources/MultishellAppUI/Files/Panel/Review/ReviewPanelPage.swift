import MultishellAppCore
import MultishellCore
import SwiftUI

/// The worktree's review comments by file, and Send at the foot; see
/// Docs/design/files/review-comments.md.
struct ReviewPanelPage: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    let page = model.reviewPage(of: worktree.id)
    let metrics = model.metrics
    VStack(spacing: 0) {
      heading(page, metrics: metrics)
      if page.isEmpty {
        PanelPageEmptyState(
          text: model.reviewEmptyText(of: worktree),
          theme: theme,
          metrics: metrics,
          glyph: SpeechBubbleShape(),
        ) {
          EmptyView()
        }
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(page.groups) { group in
              ReviewFileGroupView(
                model: model,
                worktreeID: worktree.id,
                group: group,
                theme: theme,
              )
            }
          }
          .padding(.vertical, 4)
        }
      }
      ReviewSendFooter(model: model, worktree: worktree, theme: theme)
    }
  }

  private func heading(_ page: ReviewPage, metrics: UIMetrics) -> some View {
    HStack(spacing: 8) {
      Text(t("review.title").uppercased())
        .font(metrics.font(size: metrics.small, weight: .semibold))
        .tracking(UIMetrics.filesPanelHeadingTracking)
        .foregroundStyle(theme.filesPanel.textTertiary)
      if let pending = page.pendingText {
        Text(pending)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(theme.filesPanel.textTertiary)
      }
      Spacer(minLength: 0)
      if page.showsClearSent {
        Button(t("review.clear-sent")) { model.clearSentReviewComments(in: worktree.id) }
          .buttonStyle(.plain)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(theme.filesPanel.textSecondary)
      }
    }
    .padding(.horizontal, UIMetrics.panelSideInset)
    .frame(height: metrics.paneRowHeight + 6)
  }
}
