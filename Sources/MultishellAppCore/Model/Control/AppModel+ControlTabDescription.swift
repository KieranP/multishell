import CoreGraphics
import Foundation
import MultishellCore

extension AppModel {
  func replyToDescribeTab(_ id: WorkspaceTab.ID) -> ControlReply {
    guard let tab = workspace.workspaceTab(id) else { return .refused(.noTab(id: id)) }
    let isShown = workspace.group(tab.groupID)?.shownTabID == id
    switch tab {
    case .file(let file):
      return .json(
        TabDescription(
          id: file.id,
          kind: .file,
          worktree: ControlID.worktree(file.worktreeID),
          title: title(of: file),
          isShown: isShown,
          path: file.path,
          isDeleted: fileIsGone(of: file.id),
          focusedPane: nil,
          state: nil,
          layout: nil,
        )
      )

    case .terminal(let terminal):
      return .json(
        TabDescription(
          id: terminal.id,
          kind: .terminal,
          worktree: ControlID.worktree(terminal.worktreeID),
          title: title(of: terminal),
          isShown: isShown,
          path: nil,
          isDeleted: nil,
          focusedPane: terminal.focusedSessionID,
          state: state(of: terminal),
          layout: layout(of: terminal.root),
        )
      )
    }
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
