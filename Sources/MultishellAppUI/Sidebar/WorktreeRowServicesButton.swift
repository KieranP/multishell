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
  /// Read in this body, not the row's, so a popover opening redraws the rows'
  /// buttons and not the rows.
  let isShowingServices: @MainActor @Sendable () -> Bool
  let setShowsServices: @MainActor @Sendable (Bool) -> Void
  let popover: () -> ServicesPopover

  var body: some View {
    let isShowing = isShowingServices()
    Button {
      setShowsServices(true)
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
    .popover(
      isPresented: Binding(get: { isShowing }, set: setShowsServices),
      arrowEdge: .bottom,
      content: popover,
    )
    // A row collapsed, filtered or scrolled away takes its popover with it, so
    // the model stops saying one is up.
    .onDisappear { setShowsServices(false) }
  }
}
