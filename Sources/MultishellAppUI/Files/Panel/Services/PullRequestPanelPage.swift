import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The pull request's card, the steps to its merge or the merge form, and Send
/// while a check fails or a thread is unresolved; see Docs/design/services/.
struct PullRequestPanelPage: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  @State private var showsChecks = true
  @State private var showsThreads = true

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
        let path = model.mergePath(of: pullRequest, in: worktree)
        let threads = model.unresolvedThreads(of: pullRequest, in: worktree)
        VStack(spacing: 0) {
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
              let services = model.services(of: worktree)
              let notes = [
                services.outgrownText, services.pullRequestReadProblemText, path.staleChecksNote,
                model.threadsReadProblem(of: pullRequest, in: worktree),
              ]
              ForEach(Array(notes.compactMap(\.self).enumerated()), id: \.offset) { _, note in
                ServicePageNote(text: note, theme: theme, metrics: model.metrics)
              }
              mergePath(path, of: pullRequest, threads: threads)
                .padding(.top, 10)
            }
            .padding(.bottom, 8)
          }
          PullRequestSendFooter(
            model: model,
            worktree: worktree,
            pullRequest: pullRequest,
            path: path,
            threads: threads,
            theme: theme,
          )
        }
      }
    } else if let text = page.emptyText {
      PanelPageEmptyState(
        text: text,
        palette: theme.filesPanel,
        metrics: model.metrics,
        glyph: PullRequestShape(shape: .open),
      ) {
        CreatePullRequestButton(model: model, worktree: worktree)
      }
    }
  }

  private func mergePath(
    _ path: MergePath,
    of pullRequest: PullRequest,
    threads: [PullRequestThread],
  ) -> some View {
    let host = model.pullRequestHostName(of: worktree) ?? ""
    let base = pullRequest.baseBranch
    return VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(path.steps.enumerated()), id: \.offset) { _, step in
        MergePathStepRow(
          model: model,
          worktree: worktree,
          pullRequest: pullRequest,
          path: path,
          step: step,
          threads: threads,
          base: base,
          host: host,
          theme: theme,
          showsChecks: $showsChecks,
          showsThreads: $showsThreads,
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
