import MultishellCore

extension ControlRefusal {
  private static let agentIDs = AgentCatalogue.startableIDs
    .joined(separator: ", ")

  var wording: String {
    switch self {
    case .agentNotInstalled(let id): "\(id) is not on the login shell's PATH"
    case .agentWorking: "an agent is working there; --force goes ahead anyway"
    case .alert(let title, let message): "\(title) \(message)"
    case .debugToolsOff: "debug tools are off; `multishell debug tools on` turns them on"
    case .invalidBranchName(let name): "git would refuse the branch name \(name)"
    case .invalidValue(let key, let value): "\(key) takes no value \"\(value)\""
    case .menuItemDisabled(let path): "\(path) is greyed out in the menu now"
    case .noAgent(let id): "no agent \(id); the agents are \(Self.agentIDs)"
    case .noAgentChosen: "the project prefers no agent; name one with --agent"

    case .noFindBar(let id):
      "pane \(id) has no find bar up; `multishell panes find \(id) TEXT` opens one"

    case .noFindText(let id):
      "pane \(id) has no find text; `multishell panes find \(id) TEXT` sets it"

    case .noKey(let name): "no key \(name); `multishell help panes` names them"
    case .noMenuItem(let path): "no menu item \(path); `multishell ui menu` lists them"
    case .noPane(let id): "no pane \(id); `multishell tabs list` names them"

    case .noProject(let id): "no project \(id); `multishell projects list` names them"

    case .noSetting(let key):
      "no setting \(key); `multishell config global list` and "
        + "`multishell config project PROJECT_ID list` name the keys"

    case .noTab(let id): "no tab \(id); `multishell tabs list` names them"
    case .nothingInView: "no worktree's tabs are on screen"
    case .nothingPresented: "no alert, dialog, sheet or field is up"
    case .noWindow: "the main window is closed"

    case .noWorktree(let id): "no worktree \(id); `multishell worktrees list` names them"

    case .paneNotLive(let id):
      "pane \(id) has no shell yet; `multishell worktrees select WORKTREE_ID` starts its worktree's"

    case .projectNotAdded(let path): "\(path) was not added as a project"
    case .removalVetoed(let id, let message): "worktree \(id) was not removed: \(message)"
    case .replyNotEncoded: "Multishell could not write its answer"
    case .screenshotFailed: "nothing was drawn to capture; the window or pane is off screen"
    case .tabInAnotherWorktree(let id): "tab \(id) is in another worktree"

    case .windowInFullScreen:
      "the main window is in full screen; `multishell window full-screen off` takes it out"

    case .worktreeNotCreated: "the worktree was not created"

    case .worktreeNotReady(let id):
      "worktree \(id) is being created or removed, or its directory is missing"

    case .worktreeNotRemovable(let id):
      "worktree \(id) is the project's own checkout; "
        + "`multishell projects remove PROJECT_ID` takes it away"

    case .worktreeNotRemoved(let id): "worktree \(id) was not removed"
    }
  }
}
