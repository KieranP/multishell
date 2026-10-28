import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A worktree row's pull request and CI glyphs, which open their popover.
/// Either may be missing; with neither the row draws nothing here.
struct WorktreeRowServicesButton: View {
  let services: WorktreeServices
  let theme: Theme
  let metrics: UIMetrics
  let popover: () -> ServicesPopover

  @State private var isShowingPopover = false

  var body: some View {
    Button {
      isShowingPopover = true
    } label: {
      HStack(spacing: 4) {
        if let pullRequest = services.shownPullRequest {
          PullRequestGlyph(
            mark: PullRequestMark(pullRequest),
            theme: theme,
            palette: theme.projectsPanel,
            size: metrics.serviceGlyphSize,
          )
        }
        if let run = services.ciRun {
          CIRunGlyph(
            status: run.status,
            theme: theme,
            palette: theme.projectsPanel,
            size: metrics.serviceGlyphSize,
          )
        }
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(services.tooltip)
    .accessibilityLabel(services.spokenSummary ?? "")
    .popover(isPresented: $isShowingPopover, arrowEdge: .bottom, content: popover)
  }
}
