import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// Where the merge path ends: the merge to come with what it offers, or
/// what became of the pull request with what follows it.
struct MergePathEndRow: View {
  let model: AppModel
  let worktree: Worktree
  let path: MergePath
  let base: String
  let host: String
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    HStack(alignment: .top, spacing: UIMetrics.servicePageGlyphSpacing) {
      PullRequestGlyph(
        mark: path.end.mark,
        theme: theme,
        palette: theme.filesPanel,
        size: metrics.serviceGlyphSize,
      )
      .padding(.top, metrics.mergePathGlyphDrop)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 0) {
        MergePathWords(hint: path.endHint(host: host), metrics: metrics, theme: theme) {
          Text(path.endTitle(base: base)).mergePathTitle(metrics: metrics, theme: theme)
        }
        button
          .controlSize(.small)
          .padding(.top, 9)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, UIMetrics.servicePageSideInset)
  }

  @ViewBuilder private var button: some View {
    switch path.end {
    case .offers(let action):
      Button(action.title) {
        Task { await model.perform(action, for: worktree) }
      }
      .disabled(model.isMergeActionBusy(action, of: worktree))

    case .waits:
      Button(MergeAction.merge.title) {}
        .disabled(true)

    case .closed, .merged(isOutgrown: true):
      CreatePullRequestButton(model: model, worktree: worktree)

    case .merged(isOutgrown: false):
      // The sidebar menu's own item, shown and greyed where that menu does.
      if worktree.isRemovable {
        RemoveWorktreeButton(model: model, worktree: worktree)
      }

    case .taken:
      EmptyView()
    }
  }
}
