import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The pull request in a card, whether it can merge and the checks that decide
/// it, or the merge form in their place; see Docs/design/services.md.
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
            PanelCard(theme: theme) {
              PullRequestSummary(
                model: model,
                worktree: worktree,
                pullRequest: pullRequest,
                theme: theme,
              )
            }
            let readiness = model.mergeReadiness(of: pullRequest, in: worktree)
            let action = model.mergeAction(for: readiness, in: worktree)
            MergeReadinessBanner(
              readiness: readiness,
              action: action,
              base: pullRequest.baseBranch,
              theme: theme,
              metrics: model.metrics,
              isBusy: model.isMergeActionBusy(action, of: worktree),
            ) { action in
              Task { await model.perform(action, for: worktree) }
            }
            let services = model.services(of: worktree)
            if let outgrown = services.outgrownText {
              PanelNote(text: outgrown, theme: theme, metrics: model.metrics)
            }
            if let problem = services.pullRequestReadProblemText {
              PanelNote(text: problem, theme: theme, metrics: model.metrics)
            }
            CreatePullRequestButton(model: model, worktree: worktree)
              .controlSize(.small)
              .padding(.horizontal, UIMetrics.servicePageSideInset)
              .padding(.bottom, 6)
            PanelSectionHeader(
              title: t("panel.checks", readiness.requirements.count),
              isExpanded: $showsChecks,
              theme: theme,
              metrics: model.metrics,
            )
            if showsChecks {
              ForEach(Array(readiness.requirements.enumerated()), id: \.offset) { _, requirement in
                MergeRequirementRow(
                  model: model,
                  requirement: requirement,
                  base: pullRequest.baseBranch,
                  theme: theme,
                )
              }
              if let problem = model.panelReadProblem(of: worktree) {
                PanelNote(text: problem, theme: theme, metrics: model.metrics)
              }
            }
          }
          .padding(.bottom, 8)
        }
      }
    } else if let text = page.emptyText {
      PanelEmptyState(
        text: text,
        theme: theme,
        metrics: model.metrics,
        glyph: PullRequestShape(shape: .open),
      ) {
        CreatePullRequestButton(model: model, worktree: worktree)
      }
    }
  }
}
