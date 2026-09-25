import MultishellAppCore
import MultishellCore
import SwiftUI

/// The selected worktree's panes, one row each: dot, position in a split,
/// title, chip. Bold is the one focused pane; see Docs/design/agents.md.
struct PaneRows: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    let focused = model.workspace.activeTab(in: worktree.id)?.focusedSessionID
    // Once per render, not per pane: a session lookup is a scan of them all.
    let sessions = Dictionary(
      model.workspace.sessions(in: worktree.id).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    ForEach(model.workspace.tabs(in: worktree.id)) { tab in
      ForEach(Array(tab.sessionIDs.enumerated()), id: \.element) { offset, id in
        if let session = sessions[id] {
          row(
            session, in: tab, position: .of(paneAt: offset, in: tab),
            isFocusedPane: id == focused)
        }
      }
    }
  }

  private func row(
    _ session: TerminalSession, in tab: TerminalTab, position: AgentBoardCard.Position?,
    isFocusedPane: Bool
  ) -> some View {
    let state = model.state(ofPane: session.id)
    let subagents = model.subagents(ofPane: session.id)
    let title = model.title(ofPane: session, in: tab)
    let agentID = model.agentAtThePrompt(of: session)
    return HStack(spacing: 7) {
      PaneGlyph(
        agentID: agentID,
        shellSymbol: "apple.terminal",
        state: state ?? .idle,
        surface: theme.sidebarColor,
        plainTint: isFocusedPane ? theme.textPrimary : theme.textSecondary,
        theme: theme,
        size: metrics.icon + 2
      )
      .help((state ?? .idle).displayName)
      if let position {
        PanePositionBadge(index: position.index, metrics: metrics, theme: theme)
      }
      Text(title)
        .font(.system(size: metrics.badge, weight: isFocusedPane ? .semibold : .regular))
        .foregroundStyle(isFocusedPane ? theme.textPrimary : theme.textSecondary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 4)
      if !subagents.isEmpty {
        SubagentChip(subagents: subagents, theme: theme, metrics: metrics)
      }
    }
    // The pane's glyph sits under the worktree's name, one step in from its dot.
    .padding(.leading, metrics.indent + metrics.icon + 2)
    .padding(.trailing, 8)
    .frame(height: metrics.paneRowHeight)
    .contentShape(.rect)
    .onTapGesture { model.show(pane: session.id) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AccessibilityText.pane(
        title: title, position: position, isFocusedPane: isFocusedPane, state: state,
        subagents: subagents, agent: agentID.map(model.agentDisplayName))
    )
    .accessibilityAddTraits(isFocusedPane ? [.isButton, .isSelected] : .isButton)
  }
}
