import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The pull request in a card, then the steps toward its merge ending on the
/// merge, or the merge form in their place; see Docs/design/services/.
struct PullRequestPanelPage: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  @State private var showsChecks = true

  var body: some View {
    let page = model.pullRequestPage(of: worktree)
    if case .pullRequest(let pullRequest) = page {
      if let pending = model.pendingMerge(of: worktree) {
        MergeForm(
          model: model,
          worktree: worktree,
          pullRequest: pullRequest,
          pending: pending,
          theme: theme,
        )
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            ServicePageCard(theme: theme) {
              PullRequestSummary(
                model: model,
                worktree: worktree,
                pullRequest: pullRequest,
                theme: theme,
              )
            }
            let path = model.mergePath(of: pullRequest, in: worktree)
            let services = model.services(of: worktree)
            let notes = [
              services.outgrownText, services.pullRequestReadProblemText, path.staleChecksNote,
            ]
            ForEach(Array(notes.compactMap(\.self).enumerated()), id: \.offset) { _, note in
              ServicePageNote(text: note, theme: theme, metrics: model.metrics)
            }
            mergePath(path, base: pullRequest.baseBranch)
              .padding(.top, 10)
          }
          .padding(.bottom, 8)
        }
      }
    } else if let text = page.emptyText {
      ServicePageEmptyState(
        text: text,
        theme: theme,
        metrics: model.metrics,
        glyph: PullRequestShape(shape: .open),
      ) {
        CreatePullRequestButton(model: model, worktree: worktree)
      }
    }
  }

  private func mergePath(_ path: MergePath, base: String) -> some View {
    let host = model.pullRequestHostName(of: worktree) ?? ""
    return VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(path.steps.enumerated()), id: \.offset) { _, step in
        MergePathStepRow(
          model: model,
          path: path,
          step: step,
          base: base,
          host: host,
          theme: theme,
          showsChecks: $showsChecks,
        )
      }
      MergePathEndRow(
        model: model,
        worktree: worktree,
        path: path,
        base: base,
        host: host,
        theme: theme,
      )
    }
  }
}
