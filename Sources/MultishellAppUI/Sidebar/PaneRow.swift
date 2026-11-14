import Foundation
import MultishellAppCore
import MultishellCore
import SwiftUI

/// One of the selected worktree's panes: mark, split position, title, chip, and
/// its state and time on the right. Bold is the focused pane; see agents/board-and-pane-rows.md.
struct PaneRow: View, @MainActor Equatable {
  let pane: SidebarPane
  /// The sidebar's clock, held by `SelectedWorktreePanes` as the board holds its own.
  let now: Date
  let theme: Theme
  let metrics: UIMetrics
  let select: () -> Void

  private var titleFont: Font {
    metrics.font(size: metrics.caption, weight: pane.isFocused ? .semibold : .regular)
  }

  var body: some View {
    HStack(spacing: UIMetrics.sidebarGlyphGap) {
      AgentMarkView(
        agentID: pane.agentID,
        markTint: pane.agentID.flatMap(theme.agentMarkRGB),
        plainTint: pane.isFocused
          ? theme.projectsPanel.text : theme.projectsPanel.textSecondary,
        size: metrics.paneGlyphSize,
      )
      if let position = pane.position {
        PanePositionBadge(number: position.number, metrics: metrics, palette: theme.projectsPanel)
      }
      Text(pane.title)
        .font(titleFont)
        .foregroundStyle(
          pane.isFocused ? theme.projectsPanel.text : theme.projectsPanel.textSecondary
        )
        .lineLimit(1)
        .truncationMode(.tail)
        .reservingWidth(of: UIMetrics.sidebarNameKeptSample, in: titleFont)
        .padding(.trailing, 4)
      ViewThatFits(in: .horizontal) {
        trailing(showsWorkers: true, showsElapsed: true)
        trailing(showsWorkers: false, showsElapsed: true)
        trailing(showsWorkers: false, showsElapsed: false)
      }
      .layoutPriority(1)
    }
    .padding(.leading, metrics.paneRowIndent)
    .padding(.trailing, UIMetrics.sidebarRowSideInset)
    .frame(height: metrics.paneRowHeight)
    .contentShape(.rect)
    .onTapGesture(perform: select)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.pane(pane, at: now))
    .selectableButtonTraits(isSelected: pane.isFocused)
  }

  /// Everything but `select`, which captures only the pane's id, and the clock
  /// where no time is drawn, so an idle row sits out every tick.
  static func == (a: Self, b: Self) -> Bool {
    a.pane == b.pane && (a.now == b.now || a.pane.railState == nil) && a.theme == b.theme
      && a.metrics == b.metrics
  }

  /// The worker chip and the state's dot and time; a crowded row gives up the
  /// chip, then the time, before its title.
  private func trailing(showsWorkers: Bool, showsElapsed: Bool) -> some View {
    HStack(spacing: UIMetrics.sidebarGlyphGap) {
      if showsWorkers, !pane.workers.isEmpty {
        WorkerChip(
          workers: pane.workers,
          theme: theme,
          palette: theme.projectsPanel,
          metrics: metrics,
        )
      }
      if let state = pane.railState {
        rail(state, showsElapsed: showsElapsed)
      }
    }
  }

  private func rail(_ state: SessionState, showsElapsed: Bool) -> some View {
    HStack(spacing: 4) {
      StateDot(
        state: state,
        theme: theme,
        palette: theme.projectsPanel,
        diameter: UIMetrics.inlineStateDotDiameter,
      )
      if showsElapsed, let elapsed = pane.elapsed(at: now) {
        ElapsedLabel(
          text: elapsed,
          color: theme.color(for: state, on: theme.projectsPanel),
          metrics: metrics,
        )
      }
    }
    .fixedSize()
    .help(state.displayName)
  }
}
