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
        let groups = workspace.groups(in: worktree.id)
        let shown = Set(groups.compactMap(\.shownTabID))
        return TabListing.WorktreeTabs(
          id: ControlID.worktree(worktree.id),
          name: displayName(of: worktree),
          isInView: isInView(worktree),
          activeTab: workspace.activeWorkspaceTab(in: worktree.id)?.id,
          groupShares: SplitMath.sizes(of: groups.map(\.weight), sharing: 1),
          tabs: groups.flatMap { workspace.workspaceTabs(inGroup: $0.id) }.map { tab in
            listing(of: tab, isShown: shown.contains(tab.id))
          },
        )
      },
    )
  }

  private func listing(of tab: WorkspaceTab, isShown: Bool) -> TabListing.Tab {
    switch tab {
    case .file(let file):
      return TabListing.Tab(
        id: file.id,
        kind: .file,
        title: title(of: file),
        isShown: isShown,
        path: file.path,
        isDeleted: isFileGone(of: file.id),
        focusedPane: nil,
        state: nil,
        panes: nil,
      )

    case .terminal(let terminal):
      return TabListing.Tab(
        id: terminal.id,
        kind: .terminal,
        title: title(of: terminal),
        isShown: isShown,
        path: nil,
        isDeleted: nil,
        focusedPane: terminal.focusedSessionID,
        state: state(of: terminal),
        panes: terminal.sessionIDs.compactMap(workspace.session).map { session in
          TabListing.Pane(
            id: session.id,
            title: title(ofPane: session, in: terminal),
            isLive: liveSessionIDs.contains(session.id),
            agent: agentIDAtThePrompt(of: session),
            state: state(ofPane: session.id),
          )
        },
      )
    }
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
        title: program.executableName,
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

  func replyToSelectTab(_ id: WorkspaceTab.ID) -> ControlReply {
    guard let tab = workspace.workspaceTab(id) else { return .refused(.noTab(id: id)) }
    let refusal = bringIntoView(tab.worktreeID) { store.activateTab(id) }
    if let refusal { return .refused(refusal) }
    return .done
  }

  /// A file tab runs nothing, so `force` never comes into it.
  func replyToCloseTab(_ id: WorkspaceTab.ID, force: Bool) -> ControlReply {
    guard let tab = workspace.workspaceTab(id) else { return .refused(.noTab(id: id)) }
    if case .terminal(let terminal) = tab,
      refusesOverWorkingAgent(in: terminal.sessionIDs, force: force)
    {
      return .refused(.agentWorking)
    }
    closeWithoutAsking(.tab(id), takingFocus: worktreeIDInView == tab.worktreeID)
    return .done
  }

  /// A drag onto another tab's edge, which may be in another group of the
  /// same worktree.
  func replyToMoveTab(
    _ id: WorkspaceTab.ID,
    _ placement: WorkspaceTab.Placement,
    anchor: WorkspaceTab.ID,
  ) -> ControlReply {
    guard let tab = workspace.workspaceTab(id) else { return .refused(.noTab(id: id)) }
    guard let other = workspace.workspaceTab(anchor) else { return .refused(.noTab(id: anchor)) }
    guard tab.worktreeID == other.worktreeID else {
      return .refused(.tabInAnotherWorktree(id: anchor))
    }
    let takingFocus = worktreeIDInView == tab.worktreeID
    guard moveTab(id, placement, anchor: anchor, takingFocus: takingFocus) else {
      return .refused(.noTab(id: anchor))
    }
    return .done
  }

  func replyToRenameTab(_ id: WorkspaceTab.ID, to title: String?) -> ControlReply {
    do { _ = try reachTerminalTab(id) } catch { return .refused(error) }
    renameTab(id, to: title)
    return .done
  }
}
