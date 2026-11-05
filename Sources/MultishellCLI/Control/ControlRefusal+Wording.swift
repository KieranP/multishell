import MultishellCore

extension ControlRefusal {
  private static let startableAgentList = AgentCatalogue.startableIDs.joined(separator: ", ")

  var wording: String {
    switch self {
    case .agentNotInstalled(let id): "\(id) is not on the login shell's PATH"
    case .agentWorking: "an agent is working there; --force goes ahead anyway"
    case .alert(let title, let message): "\(title) \(message)"
    case .autoRenameUnavailable(let id): "Auto Rename is greyed out for worktree \(id)"
    case .debugToolsOff: "debug tools are off; `multishell debug tools on` turns them on"
    case .fileNotOpenable(let path): "\(path) is not a file of the worktree that opens as text"
    case .fileTabNotRead(let id): "tab \(id) is still being read; ask again once it is"

    case .fileTabShowsNotice(let id):
      "tab \(id) shows a notice, its file too large, binary, missing or unreadable"

    case .filesPanelListsNoFiles:
      "the Files panel is shut, or open on a page with no files: "
        + "`multishell config global set filesPanelMode files` turns to its list, and where "
        + "it is shut `multishell ui menu \"View > Files Panel\"` opens it"

    case .gitNotFound: "git is not on the login shell's PATH, so nothing is read from it"
    case .invalidBranchName(let name): "git would refuse the branch name \(name)"
    case .invalidValue(let key, let value): "\(key) takes no value \"\(value)\""
    case .menuItemDisabled(let path): "\(path) is greyed out in the menu now"
    case .noAgent(let id): "no agent \(id); the agents are \(Self.startableAgentList)"
    case .noAgentChosen: "the project prefers no agent; name one with --agent"

    case .noChangeThatWay(let id): "tab \(id) has no change that way"

    case .noFilesFolder(let path):
      "the Files panel lists no folder \(path); `multishell files list` names its rows"

    case .noFindBar(let id):
      "\(id) has no find bar up; `multishell panes find \(id) TEXT` opens a pane's, "
        + "`multishell tabs find \(id) TEXT` a file tab's"

    case .noFindText(let id):
      "\(id) has no find text; `multishell panes find \(id) TEXT` sets a pane's, "
        + "`multishell tabs find \(id) TEXT` a file tab's"

    case .noHiddenWorktrees(let id):
      "project \(id) has no hidden worktrees; `multishell worktrees hide WORKTREE_ID` hides one"

    case .noGroups(let id):
      "worktree \(id) has no tabs, so no groups; `multishell tabs open \(id)` opens one"

    case .noKey(let name): "no key \(name); `multishell help panes` names them"
    case .noMenuItem(let path): "no menu item \(path); `multishell ui menu` lists them"
    case .noPane(let id): "no pane \(id); `multishell tabs list` names them"

    case .noServicePage(.ciRuns, let id): "worktree \(id) has no CI run to show"
    case .noServicePage(.pullRequest, let id): "worktree \(id) has no pull request to show"

    case .noProject(let id): "no project \(id); `multishell projects list` names them"

    case .noSettingsPage(let page, let pages):
      "no \(page.rawValue) page in the settings asked for, whose pages are "
        + pages.map(\.rawValue).joined(separator: ", ")

    case .noProjectChosen:
      "no project is selected to show the settings of; name one with its PROJECT_ID"

    case .noSetting(let key):
      "no setting \(key); `multishell config global list` and "
        + "`multishell config project PROJECT_ID list` name the keys"

    case .noSplit(let id, let path):
      "tab \(id) has no split at [\(path.map(String.init).joined(separator: ","))]; "
        + "`multishell tabs show \(id)` prints its layout"

    case .noSwitcherRow: "the quick switcher lists no row to choose"

    case .noSwitcherScope(let name, let scopes):
      "the quick switcher has no scope \(name); its scopes are \(scopes.joined(separator: ", "))"

    case .noTab(let id): "no tab \(id); `multishell tabs list` names them"
    case .nothingInView: "no worktree's tabs are on screen"
    case .nothingPresented: "no alert, dialog, sheet or field is up"
    case .noWindow: "the main window is closed"

    case .noWorktree(let id): "no worktree \(id); `multishell worktrees list` names them"

    case .onlyTabInGroup(let id): "tab \(id) is its group's only tab"

    case .paneNotLive(let id):
      "pane \(id) has no shell yet; `multishell worktrees select WORKTREE_ID` starts its worktree's"

    case .projectBesideItself(let id): "project \(id) moves beside another project, not itself"
    case .projectFolderMissing(let id): "project \(id)'s folder is gone"
    case .projectNotAdded(let path): "\(path) was not added as a project"
    case .projectWithNoWorktree(let id): "project \(id) has no worktree to show"
    case .quickSwitcherClosed: "the quick switcher closed before a row was chosen"
    case .removalVetoed(let id, let message): "worktree \(id) was not removed: \(message)"
    case .replyNotEncoded: "Multishell could not write its answer"
    case .screenshotFailed: "nothing was drawn to capture; the window or pane is off screen"
    case .serviceStandInUnreadable(let reason): "the stand-in was not read: \(reason)"

    case .shareBelowMinimum(let points):
      "a side would be smaller than the \(Int(points)) points a drag leaves it"

    case .stepNotYetTaken(let id):
      "tab \(id) has not yet taken its last step; ask again once it has drawn"

    case .switcherRowGone:
      "the row chosen leads nowhere now; its worktree, tab or pane has gone"

    case .tabAlreadyThere(let id): "tab \(id) is in that worktree already"
    case .tabInAnotherWorktree(let id): "tab \(id) is in another worktree"
    case .tabNotMoved(let id): "tab \(id) was not moved"

    case .tabShowsAFile(let id): "tab \(id) shows a file; only a terminal tab takes that"

    case .tabNotShown(let id):
      "tab \(id) is not on screen; `multishell tabs select \(id)` shows it"

    case .tabShowsNoFile(let id): "tab \(id) is a terminal's, with no file's bar"

    case .widthOutOfRange(let minimum, let maximum):
      "the width takes \(Int(minimum)) to \(Int(maximum)) points"

    case .windowCovered: "the main window is covered or on another Space; bring it forward"
    case .windowMinimized: "the main window is minimized; bring it back from the Dock"

    case .windowInFullScreen:
      "the main window is in full screen; `multishell window full-screen off` takes it out"

    case .wrongShareCount(let expected): "that takes \(expected) shares, one a side"

    case .worktreeNotCreated: "the worktree was not created"

    case .worktreeNotReady(let id):
      "worktree \(id) is being created or removed, or its directory is missing"

    case .worktreeNotRemovable(let id):
      "worktree \(id) is the project's own checkout; "
        + "`multishell projects remove PROJECT_ID` takes it away"

    case .worktreeNotRemoved(let id): "worktree \(id) was not removed"
    case .worktreeNotHideable(let id): "worktree \(id) is the project's own checkout, never hidden"
    }
  }
}
