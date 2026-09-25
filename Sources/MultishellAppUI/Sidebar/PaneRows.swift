import MultishellAppCore
import MultishellCore
import SwiftUI

/// The selected worktree's panes, one `PaneRow` each, in tab order.
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
    _ session: TerminalSession, in tab: TerminalTab, position: PanePosition?,
    isFocusedPane: Bool
  ) -> some View {
    let agentID = model.agentAtThePrompt(of: session)
    return PaneRow(
      title: model.title(ofPane: session, in: tab),
      position: position,
      isFocusedPane: isFocusedPane,
      state: model.state(ofPane: session.id),
      subagents: model.subagents(ofPane: session.id),
      agentID: agentID,
      agentName: agentID.map(model.agentDisplayName),
      theme: theme,
      metrics: metrics,
      select: { [model] in model.show(pane: session.id) }
    )
    .equatable()
  }
}
