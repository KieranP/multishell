import CoreGraphics
import Foundation
import MultishellCore

extension AppModel {
  func answerDescribeTab(_ id: TerminalTab.ID) -> ControlReply {
    guard let tab = workspace.tab(id) else { return .refused(.noTab(id: id)) }
    let shown = Set(workspace.shownTabs(in: tab.worktreeID).map(\.id))
    return .json(
      TabDescription(
        id: tab.id,
        worktree: ControlID.worktree(tab.worktreeID),
        title: title(of: tab),
        isShown: shown.contains(tab.id),
        focusedPane: tab.focusedSessionID,
        state: state(of: tab),
        layout: layout(of: tab.root),
      )
    )
  }

  private func layout(of node: PaneNode) -> TabDescription.Layout {
    switch node {
    case .terminal(let id):
      let frame = host.frame(of: id).map { rect in
        TabDescription.Frame(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
      }
      return TabDescription.Layout(pane: id, frame: frame, axis: nil, shares: nil, children: nil)

    case .split(let axis, let children, let weights):
      return TabDescription.Layout(
        pane: nil,
        frame: nil,
        axis: axis,
        shares: SplitMath.sizes(of: weights, sharing: 1),
        children: children.map(layout),
      )
    }
  }
}
