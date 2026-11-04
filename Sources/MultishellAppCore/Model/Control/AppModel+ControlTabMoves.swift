import Foundation
import MultishellCore

extension AppModel {
  /// A drop on another worktree's row: the shells go with the tab, and that
  /// worktree comes into view, as after the drag.
  func replyToMoveTabToWorktree(_ id: WorkspaceTab.ID, to worktreeID: String) -> ControlReply {
    let tab: TerminalTab
    do { tab = try reachTerminalTab(id) } catch { return .refused(error) }
    guard let worktree = worktree(withControlID: worktreeID) else {
      return .refused(.noWorktree(id: worktreeID))
    }
    guard tab.worktreeID != worktree.id else { return .refused(.tabAlreadyThere(id: id)) }
    if isBusy(tab.worktreeID) {
      return .refused(.worktreeNotReady(id: ControlID.worktree(tab.worktreeID)))
    }
    guard !isBusy(worktree.id) else { return .refused(.worktreeNotReady(id: worktreeID)) }
    // A folder gone raises its alert, which answers in place of this.
    guard moveTab(id, toWorktree: worktree.id) else { return .refused(.tabNotMoved(id: id)) }
    return .done
  }

  /// The tab's Move to New Group, a group of its own to the right of its own;
  /// in a worktree out of view the keyboard stays where it is.
  func replyToMoveTabToNewGroup(_ id: WorkspaceTab.ID) -> ControlReply {
    guard let tab = workspace.workspaceTab(id) else { return .refused(.noTab(id: id)) }
    guard canMoveTabToNewGroup(from: tab.groupID) else { return .refused(.onlyTabInGroup(id: id)) }
    let takingFocus = worktreeIDInView == tab.worktreeID
    guard moveTab(id, .after, toNewGroupOf: tab.groupID, takingFocus: takingFocus) else {
      return .refused(.tabNotMoved(id: id))
    }
    return .done
  }
}
