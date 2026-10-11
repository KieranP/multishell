import Foundation
import MultishellCore

extension AppModel {
  func replyToDescribePane(_ id: TerminalSession.ID) -> ControlReply {
    guard let tab = workspace.tab(owning: id), let session = workspace.session(id) else {
      return .refused(.noPane(id: id))
    }
    return .json(
      PaneDescription(
        id: id,
        tab: tab.id,
        worktree: ControlID.worktree(tab.worktreeID),
        title: title(ofPane: session, in: tab),
        isLive: liveSessionIDs.contains(id),
        isFocused: tab.focusedSessionID == id,
        agent: session.agentID,
        state: state(ofPane: id),
        workers: workers(ofPane: id).map(PaneDescription.Worker.init),
        find: findBarSessionIDs.contains(id)
          ? PaneDescription.Find(
            text: findText(of: id),
            total: searchCounts[id]?.total,
            selected: searchCounts[id]?.selected,
          ) : nil,
      )
    )
  }
}
