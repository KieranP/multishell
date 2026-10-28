import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The panel's CI page: the branch's newest run in a card, its workflows and
/// jobs under Latest Run, and its earlier runs; see Docs/design/services.md.
struct CIPanelPage: View {
  /// Often enough that a run's "Started 4 minutes ago" is never a minute out.
  private static let ageTickInterval: Duration = .seconds(30)

  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  @State private var showsLatestRun = true
  @State private var showsEarlierRuns = false
  @State private var now = Date()

  var body: some View {
    let metrics = model.metrics
    let page = model.ciPage(of: worktree)
    if case .run(let run) = page {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          CIRunCard(model: model, worktree: worktree, run: run, now: now, theme: theme)
          PanelSectionHeader(
            title: t("panel.latest-run"),
            isExpanded: $showsLatestRun,
            theme: theme,
            metrics: metrics,
          )
          if showsLatestRun {
            CIWorkflowList(model: model, worktree: worktree, run: run, theme: theme)
          }
          let earlier = model.earlierCIRuns(of: worktree)
          if !earlier.isEmpty {
            PanelSectionHeader(
              title: t("panel.earlier-runs", earlier.count),
              isExpanded: $showsEarlierRuns,
              theme: theme,
              metrics: metrics,
            )
            if showsEarlierRuns {
              ForEach(earlier) { run in
                CIHistoryRow(model: model, worktree: worktree, run: run, now: now, theme: theme)
              }
            }
          }
          if let problem = model.panelReadProblem(of: worktree) {
            PanelNote(text: problem, theme: theme, metrics: metrics)
          }
        }
        .padding(.bottom, 8)
      }
      .ticking($now, every: Self.ageTickInterval)
    } else if let text = page.emptyText {
      PanelEmptyState(
        text: text,
        theme: theme,
        metrics: metrics,
        glyph: CIRunShape(status: .passed),
      ) {
        EmptyView()
      }
    }
  }
}
