import MultishellCore

extension ControlRefusal {
  private static let startableAgentList = AgentCatalogue.startableIDs.joined(separator: ", ")

  var wording: String {
    switch self {
    case .actionNotFound(let name):
      "no action \(name) here; `multishell actions list WORKTREE_ID` names them"

    case .actionNotTrusted(let name):
      "\(name) is .multishell.json's, which has not been trusted; its project's Actions settings"
        + " page trusts it"

    case .actionTabOccupied(let name):
      "something still runs in \(name)'s tab; --restart stops it and runs \(name) again"

    case .agentNotInstalled(let id): "\(id) is not on the login shell's PATH"
    case .agentWorking: "an agent is working there; --force goes ahead anyway"
    case .alert(let title, let message): "\(title) \(message)"
    case .autoRenameUnavailable(let id): "Auto Rename is greyed out for worktree \(id)"

    case .baseUpdateUnavailable(let id):
      "worktree \(id) has no base to update from: it is detached, bare, on the default "
        + "branch itself, or its project has none"

    case .checksNotRead(let id, let reason):
      "worktree \(id)'s checks could not be read, so nothing was sent: \(reason)"

    case .commitsOnNoBranch(let id, let count?):
      "worktree \(id) holds \(count) commit(s) on no branch, which removing it would lose; "
        + "--force goes ahead anyway"

    case .commitsOnNoBranch(let id, nil):
      "worktree \(id)'s commits on no branch could not be counted; --force goes ahead anyway"

    case .debugToolsOff: "debug tools are off; `multishell debug tools on` turns them on"

    case .fileNotOpenable(let path):
      "\(path) is not a file of the worktree that opens as text or an image"

    case .fileTabNotRead(let id): "tab \(id) is still being read; ask again once it is"

    case .fileTabShowsImage(let id): "tab \(id) shows an image, which has no lines"

    case .fileTabShowsNotice(let id):
      "tab \(id) shows a notice, its file too large, binary, missing or unreadable"

    case .filesPanelListsNoFiles:
      "the Files panel is shut, or open on a page with no files: "
        + "`multishell ui menu \"View > Files Pane\"` opens it on its list"

    case .gitNotFound: "git is not on the login shell's PATH, so nothing is read from it"

    case .handoffUnderWay(let id):
      "worktree \(id)'s pull request page has a Send under way; ask again once it has sent"

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
        + "`multishell tabs find \(id) TEXT` a file or All changes tab's"

    case .noFindText(let id):
      "\(id) has no find text; `multishell panes find \(id) TEXT` sets a pane's, "
        + "`multishell tabs find \(id) TEXT` a file or All changes tab's"

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

    case .noProjectHolding(let path):
      "no project holds \(path); name a PROJECT_ID, or add it with `multishell projects add`"

    case .noRemovedLines(let path):
      "those lines of \(path) hold no removed line; leave out --removed to comment "
        + "on the file on disk"

    case .noReviewLines(let path): "the tab of \(path) holds no such lines on that side"

    case .noReviewTab(let path):
      "no file tab of the worktree shows \(path); `multishell tabs open-file` opens one"

    case .noRecipient(let id):
      "worktree \(id) has no pane with an agent to send to, "
        + "or not the one named; `multishell tabs list` names its panes"

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
    case .nothingPresented: "no alert, dialog, sheet, quick switcher or name field is up"

    case .nothingToHandoff(.ciRuns, let id):
      "worktree \(id)'s CI page has no failure checked and not sent already; it reads "
        + "the newest run's jobs only while shown: `multishell ui show ci \(id)`"

    case .nothingToHandoff(.pullRequest, let id):
      "worktree \(id)'s pull request has no failing check or unresolved thread checked "
        + "and not sent already"

    case .nothingToSend(let id): "worktree \(id) has no review comment waiting to be sent"
    case .noWindow: "the main window is closed"

    case .noWorktree(let id): "no worktree \(id); `multishell worktrees list` names them"

    case .onlyTabInGroup(let id): "tab \(id) is its group's only tab"

    case .threadsNotRead(let id, let reason):
      "worktree \(id)'s review threads could not be read, so nothing was sent: \(reason)"

    case .paneNotLive(let id):
      "pane \(id) has no shell yet; `multishell worktrees select WORKTREE_ID` starts its worktree's"

    case .pickingCommits(let id):
      "worktree \(id) has a cherry-pick, revert or git am stopped partway; finish it "
        + "with its own --continue, or abort it, first"

    case .projectBesideItself(let id): "project \(id) moves beside another project, not itself"
    case .projectFolderMissing(let id): "project \(id)'s folder is gone"
    case .projectNotAdded(let path): "\(path) was not added as a project"
    case .projectWithNoWorktree(let id): "project \(id) has no worktree to show"
    case .quickSwitcherClosed: "the quick switcher closed before a row was chosen"
    case .removalVetoed(let id, let message): "worktree \(id) was not removed: \(message)"
    case .replyNotEncoded: "Multishell could not write its answer"

    case .rewritesPushedBranch(let id):
      "worktree \(id)'s branch is on its remote, so after a rebase its next push needs "
        + "--force-with-lease; --rewrite-pushed rebases anyway"

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

    case .tabShowsAllChanges(let id):
      "tab \(id) shows all changes, with no panes and no one file's bar"

    case .tabNotShown(let id):
      "tab \(id) is not on screen; `multishell tabs select \(id)` shows it"

    case .tabShowsNoFile(let id): "tab \(id) is a terminal's, with no file's bar"

    case .uncommittedChanges(let id, let changes):
      "worktree \(id) has uncommitted changes, which are never stashed; commit them first:\n"
        + Self.listed(changes)

    case .unfinishedUpdate(let id, let method):
      "worktree \(id) is partway through a \(method.rawValue); `\(method.continueCommand)` "
        + "finishes it and `git \(method.rawValue) --abort` undoes it"

    case .updateUnderWay(let id):
      "worktree \(id) is busy with its base: a check, the fetch, the merge or rebase, or an "
        + "Abort is under way"

    case .widthOutOfRange(let minimum, let maximum):
      "the width takes \(Int(minimum)) to \(Int(maximum)) points"

    case .windowCovered: "the main window is covered or on another Space; bring it forward"
    case .windowMinimized: "the main window is minimized; bring it back from the Dock"

    case .windowInFullScreen:
      "the main window is in full screen; `multishell window full-screen off` takes it out"

    case .wrongShareCount(let expected): "that takes \(expected) shares, one a side"

    case .worktreeNotCreated: "the worktree was not created"

    case .worktreeNotReady(let id):
      "worktree \(id) is being created or removed, shows a failed stage until its pane's "
        + "Dismiss, or its directory is missing"

    case .worktreeNotRemovable(let id):
      "worktree \(id) is the project's own checkout; "
        + "`multishell projects remove PROJECT_ID` takes it away"

    case .worktreeNotRemoved(let id): "worktree \(id) was not removed"
    case .worktreeNotHideable(let id): "worktree \(id) is the project's own checkout, never hidden"
    }
  }

  /// One change a line, indented, those past the alert's limit counted.
  private static func listed(_ changes: [String]) -> String {
    let listed = UncommittedChangeList(changes)
    var lines = listed.shown.map { "  " + $0 }
    if listed.unlisted > 0 { lines.append("  and \(listed.unlisted) more") }
    return lines.joined(separator: "\n")
  }
}
