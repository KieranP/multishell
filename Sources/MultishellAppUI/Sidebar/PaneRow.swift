import MultishellAppCore
import MultishellCore
import SwiftUI

/// One of the selected worktree's panes: glyph, position in a split, title,
/// chip. Bold is the one focused pane; see Docs/design/agents.md.
struct PaneRow: View {
  let title: String
  let position: PanePosition?
  let isFocusedPane: Bool
  let state: SessionState?
  let workers: [Worker]
  let agentID: String?
  let agentName: String?
  let theme: Theme
  let metrics: UIMetrics
  let select: () -> Void

  var body: some View {
    HStack(spacing: 7) {
      PaneGlyph(
        agentID: agentID,
        state: state ?? .idle,
        ringFill: theme.sidebarColor,
        plainTint: isFocusedPane ? theme.textPrimary : theme.textSecondary,
        theme: theme,
        size: metrics.paneGlyphSize
      )
      .help((state ?? .idle).displayName)
      if let position {
        PanePositionBadge(number: position.number, metrics: metrics, theme: theme)
      }
      Text(title)
        .font(.system(size: metrics.badge, weight: isFocusedPane ? .semibold : .regular))
        .foregroundStyle(isFocusedPane ? theme.textPrimary : theme.textSecondary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 4)
      if !workers.isEmpty {
        WorkerChip(workers: workers, theme: theme, metrics: metrics)
      }
    }
    // The pane's glyph sits under the worktree's name, one step in from its dot.
    .padding(.leading, metrics.indent + metrics.sidebarGlyphColumn)
    .padding(.trailing, 8)
    .frame(height: metrics.paneRowHeight)
    .contentShape(.rect)
    .onTapGesture(perform: select)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AccessibilityText.pane(
        title: title, position: position, isFocusedPane: isFocusedPane, state: state,
        workers: workers, agentName: agentName)
    )
    .accessibilityAddTraits(isFocusedPane ? [.isButton, .isSelected] : .isButton)
  }
}

/// Everything but `select`, which captures only the pane's id; see
/// `WorktreeRow`'s.
extension PaneRow: @MainActor Equatable {
  static func == (a: PaneRow, b: PaneRow) -> Bool {
    a.title == b.title && a.position == b.position && a.isFocusedPane == b.isFocusedPane
      && a.state == b.state && a.workers == b.workers && a.agentID == b.agentID
      && a.agentName == b.agentName && a.theme == b.theme && a.metrics == b.metrics
  }
}
