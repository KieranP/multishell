import Foundation
import MultishellCore

extension AppModel {
  /// `nil` lists every worktree's tabs.
  func replyToListTabs(of id: String?) -> ControlReply {
    var worktrees = workspace.worktrees
    if let id {
      guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
      worktrees = [worktree]
    }
    return .json(tabListing(of: worktrees))
  }

  private func tabListing(of worktrees: [Worktree]) -> TabListing {
    TabListing(
      worktreeInView: worktreeInView.map { ControlID.worktree($0.id) },
      worktrees: worktrees.map { worktree in
        let shown = Set(workspace.shownTabs(in: worktree.id).map(\.id))
        return TabListing.WorktreeTabs(
          id: ControlID.worktree(worktree.id),
          name: displayName(of: worktree),
          isInView: isInView(worktree),
          activeTab: workspace.activeTab(in: worktree.id)?.id,
          tabs: workspace.tabs(in: worktree.id).map { tab in
            TabListing.Tab(
              id: tab.id,
              title: title(of: tab),
              isShown: shown.contains(tab.id),
              focusedPane: tab.focusedSessionID,
              state: state(of: tab),
              panes: tab.sessionIDs.compactMap(workspace.session).map { session in
                TabListing.Pane(
                  id: session.id,
                  title: title(ofPane: session, in: tab),
                  isLive: liveSessionIDs.contains(session.id),
                  agent: session.agentID,
                  state: state(ofPane: session.id),
                )
              },
            )
          },
        )
      },
    )
  }

  /// In the background unless its worktree is in view; a worktree with no
  /// shells yet starts its saved tabs with it.
  func replyToNewTab(_ order: NewTabOrder) -> ControlReply {
    let id = order.worktreeID
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    guard requireShellReady(worktree) else { return .refused(.worktreeNotReady(id: id)) }
    let opened: TerminalTab?
    if let command = order.command, let program = command.first {
      let (shell, handOver) = TabCommand.loginShell(handingOverTo: shellPath(for: worktree))
      opened = store.openTab(
        in: worktree.id,
        title: URL(fileURLWithPath: program).lastPathComponent,
        command: TabCommand.running(command, shell: shell, handOver: handOver),
      )
    } else {
      let fallback = effectiveAgentID(for: worktree)
      switch agentToStart(order.agentID, task: order.task, otherwise: fallback) {
      case .failure(let refusal): return .refused(refusal)

      case .success(let agentID?):
        opened = addAgentTab(agentID, in: worktree, group: nil, task: order.task ?? "")

      case .success(nil): opened = store.openTab(in: worktree.id)
      }
    }
    guard let opened else { return .refused(.worktreeNotReady(id: id)) }
    warmWorktrees.insert(worktree.id)
    reconcileSessions(takingFocus: isInView(worktree))
    return .json(["tab": opened.id, "pane": opened.focusedSessionID])
  }

  func replyToSelectTab(_ id: TerminalTab.ID) -> ControlReply {
    guard let tab = workspace.tab(id) else { return .refused(.noTab(id: id)) }
    if let refusal = refusalToBringIntoView(tab) { return .refused(refusal) }
    activate(tab)
    return .done
  }

  func replyToCloseTab(_ id: TerminalTab.ID, force: Bool) -> ControlReply {
    guard let tab = workspace.tab(id) else { return .refused(.noTab(id: id)) }
    if refusesOverWorkingAgent(in: tab.sessionIDs, force: force) { return .refused(.agentWorking) }
    closeWithoutAsking(.tab(id), takingFocus: isWorktreeInView(of: tab))
    return .done
  }

  /// A drag onto another tab's edge, which may be in another group of the
  /// same worktree.
  func replyToMoveTab(_ id: TerminalTab.ID, before: Bool, anchor: TerminalTab.ID) -> ControlReply {
    guard let tab = workspace.tab(id) else { return .refused(.noTab(id: id)) }
    guard let other = workspace.tab(anchor) else { return .refused(.noTab(id: anchor)) }
    guard tab.worktreeID == other.worktreeID else {
      return .refused(.tabInAnotherWorktree(id: anchor))
    }
    let placement: TerminalTab.Placement = before ? .before : .after
    guard moveTab(id, placement, anchor: anchor, takingFocus: isWorktreeInView(of: tab)) else {
      return .refused(.noTab(id: anchor))
    }
    return .done
  }

  func replyToRenameTab(_ id: TerminalTab.ID, to title: String?) -> ControlReply {
    guard workspace.tab(id) != nil else { return .refused(.noTab(id: id)) }
    renameTab(id, to: title)
    return .done
  }
}
