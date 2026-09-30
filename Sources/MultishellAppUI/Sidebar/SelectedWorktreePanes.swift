import MultishellAppCore
import MultishellCore
import SwiftUI

/// The selected worktree's panes, one `PaneRow` each, in tab order.
struct SelectedWorktreePanes: View {
  let model: AppModel
  let panes: [SidebarPane]
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    ForEach(panes) { pane in
      PaneRow(
        title: pane.title,
        position: pane.position,
        isFocusedPane: pane.isFocused,
        state: pane.state,
        subagents: pane.subagents,
        agentID: pane.agentID,
        agentName: pane.agentName,
        theme: theme,
        metrics: metrics,
        select: { [model] in model.show(pane: pane.id) }
      )
      .equatable()
    }
  }
}
