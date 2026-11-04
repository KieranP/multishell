import Foundation
import MultishellCore

/// Clear Status, from a board card, a tab's menu or a worktree's.
extension AppModel {
  func replyToClearPaneState(_ id: TerminalSession.ID) -> ControlReply {
    if let refusal = refusalToReachPane(id) { return .refused(refusal) }
    clearState(ofPane: id)
    return .done
  }

  func replyToClearTabState(_ id: TerminalTab.ID) -> ControlReply {
    let tab: TerminalTab
    do { tab = try reachTerminalTab(id) } catch { return .refused(error) }
    clearState(of: tab)
    return .done
  }

  func replyToClearWorktreeState(_ id: String) -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    clearState(ofWorktree: worktree.id)
    return .done
  }
}
