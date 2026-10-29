import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A worktree row's pull request and CI glyphs, each opening its page of the
/// panel. Either may be missing; with neither the row draws nothing here.
struct WorktreeRowServicesButtons: View {
  let services: WorktreeServices
  let theme: Theme
  let metrics: UIMetrics
  let showPullRequest: () -> Void
  let showCIRuns: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      if let pullRequest = services.shownPullRequest {
        Button(action: showPullRequest) {
          PullRequestGlyph(
            mark: PullRequestMark(pullRequest),
            theme: theme,
            palette: theme.projectsPanel,
            size: metrics.serviceGlyphSize,
          )
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(services.spokenPullRequest ?? "")
      }
      if let run = services.ciRun {
        Button(action: showCIRuns) {
          CIRunGlyph(
            status: run.status,
            theme: theme,
            palette: theme.projectsPanel,
            size: metrics.serviceGlyphSize,
          )
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(services.ciRunText ?? "")
      }
    }
    .help(services.tooltip)
  }
}
