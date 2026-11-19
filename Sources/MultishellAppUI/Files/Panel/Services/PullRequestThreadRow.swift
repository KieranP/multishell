import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// An unresolved thread: its author, place and two lines of its first comment,
/// opening on the host at a click, then its checkbox or sent bubble.
struct PullRequestThreadRow: View {
  let model: AppModel
  let thread: PullRequestThread
  let candidate: HandoffCandidate
  let worktreeID: Worktree.ID
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    let first = thread.comments.first
    HStack(alignment: .top, spacing: 8) {
      Button {
        model.openThread(thread)
      } label: {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(thread.authorName)
              .font(metrics.font(size: metrics.secondary, weight: .semibold))
              .foregroundStyle(theme.filesPanel.text)
              .lineLimit(1)
              .fixedSize()
            Text(thread.placeLabel)
              .font(.system(size: metrics.caption, design: .monospaced))
              .foregroundStyle(theme.filesPanel.textSecondary)
              .lineLimit(1)
              .truncationMode(.head)
            if thread.isOutdated {
              ReviewChipLabel(
                chip: .outdated,
                palette: theme.filesPanel,
                theme: theme,
                metrics: metrics,
              )
              .fixedSize()
            }
          }
          Text(first?.body ?? "")
            .font(metrics.font(size: metrics.secondary))
            .foregroundStyle(theme.filesPanel.text)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(thread.webPage == nil)
      .accessibilityElement(children: .combine)
      HandoffItemControl(
        model: model,
        candidate: candidate,
        worktreeID: worktreeID,
        itemName: thread.placeLabel,
        theme: theme,
      )
    }
    .padding(.vertical, 5)
  }
}
