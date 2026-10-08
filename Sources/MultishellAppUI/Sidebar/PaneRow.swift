import MultishellAppCore
import MultishellCore
import SwiftUI

/// One of the selected worktree's panes: glyph, position in a split, title,
/// chip. Bold is the one focused pane; see Docs/design/agents.md.
struct PaneRow: View {
  let pane: SidebarPane
  let theme: Theme
  let metrics: UIMetrics
  let select: () -> Void

  var body: some View {
    HStack(spacing: 7) {
      PaneGlyph(
        agentID: pane.agentID,
        state: pane.state.shownState,
        ringFill: theme.sidebarColor,
        plainTint: pane.isFocused ? theme.textPrimary : theme.textSecondary,
        theme: theme,
        size: metrics.paneGlyphSize
      )
      .help(pane.state.shownState.displayName)
      if let position = pane.position {
        PanePositionBadge(number: position.number, metrics: metrics, theme: theme)
      }
      Text(pane.title)
        .font(.system(size: metrics.badge, weight: pane.isFocused ? .semibold : .regular))
        .foregroundStyle(pane.isFocused ? theme.textPrimary : theme.textSecondary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 4)
      if !pane.workers.isEmpty {
        WorkerChip(workers: pane.workers, theme: theme, metrics: metrics)
      }
    }
    .padding(.leading, metrics.paneRowIndent)
    .padding(.trailing, 8)
    .frame(height: metrics.paneRowHeight)
    .contentShape(.rect)
    .onTapGesture(perform: select)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.pane(pane))
    .selectableButtonTraits(isSelected: pane.isFocused)
  }
}

/// Everything but `select`, which captures only the pane's id; see
/// `WorktreeRow`'s.
extension PaneRow: @MainActor Equatable {
  static func == (a: PaneRow, b: PaneRow) -> Bool {
    a.pane == b.pane && a.theme == b.theme && a.metrics == b.metrics
  }
}
