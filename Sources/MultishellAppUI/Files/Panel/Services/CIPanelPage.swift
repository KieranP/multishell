import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The panel's CI page: the newest run's card, workflows and jobs, earlier runs,
/// and Send while it has failures; see Docs/design/services/marks-and-pages.md.
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
      let listing = model.ciWorkflowListing(of: run, sendsFailures: true)
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            CIRunCard(model: model, worktree: worktree, run: run, now: now, theme: theme)
            latestRunHeader(listing, metrics: metrics)
            if showsLatestRun {
              CIWorkflowList(
                model: model,
                worktree: worktree,
                run: run,
                listing: listing,
                theme: theme,
              )
            }
            let earlier = model.earlierCIRuns(of: worktree)
            if !earlier.isEmpty {
              ServicePageSectionHeader(
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
              ServicePageNote(text: problem, theme: theme, metrics: metrics)
            }
          }
          .padding(.bottom, 8)
        }
        .ticking($now, every: Self.ageTickInterval)
        CISendFooter(model: model, worktree: worktree, listing: listing, theme: theme)
      }
    } else if let text = page.emptyText {
      PanelPageEmptyState(
        text: text,
        palette: theme.filesPanel,
        metrics: metrics,
        glyph: CIRunShape(status: .passed),
      ) {
        EmptyView()
      }
    }
  }

  private func latestRunHeader(_ listing: CIWorkflowListing, metrics: UIMetrics) -> some View {
    let candidates = listing.candidates
    return ServicePageSectionHeader(
      title: t("panel.latest-run"),
      isExpanded: $showsLatestRun,
      theme: theme,
      metrics: metrics,
      detail: model.handoffToSendText(
        of: candidates,
        isCollapsed: !showsLatestRun,
        in: worktree.id,
      ),
    ) {
      if let state = model.handoffGroupState(of: candidates, in: worktree.id) {
        HandoffCheckbox(state: state, label: t("handoff.send-all-failures")) {
          model.toggleHandoffGroup(candidates, in: worktree.id)
        }
        .frame(width: metrics.handoffSlotWidth, alignment: .trailing)
      }
    }
  }
}
