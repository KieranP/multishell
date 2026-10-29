import Foundation

/// Why the app did not do what a request asked. Data, not words: the
/// helper says each in English, as its output stays (translation.md).
public enum ControlRefusal: Error, Codable, Equatable, Sendable {
  /// Not on the login shell's PATH, so the tab would open as a plain shell.
  case agentNotInstalled(id: String)
  case agentWorking
  /// The app raised an alert instead; its words, in the app's language.
  case alert(title: String, message: String)
  /// Auto Rename is greyed out for the worktree.
  case autoRenameUnavailable(id: String)
  case debugToolsOff
  /// Not a file the worktree holds that opens as text, which a click beeps at.
  case fileNotOpenable(path: String)
  /// Shut, or showing a pull request's or CI's page, which lists no files.
  case filesPanelListsNoFiles
  /// A file tab's rows are still being read, so a find step has nothing to step.
  case fileTabNotRead(id: UUID)
  /// No git on the login shell's PATH, which every git read needs.
  case gitNotFound
  case invalidBranchName(String)
  case invalidValue(key: String, value: String)
  /// Greyed out in the menu now, as a click would find it.
  case menuItemDisabled(path: String)
  /// No catalogue agent has the id.
  case noAgent(id: String)
  case noAgentChosen
  /// The file tab's view has no change that way, as its arrow is greyed.
  case noChangeThatWay(id: UUID)
  /// The Files panel lists no folder at that path.
  case noFilesFolder(path: String)
  /// A find step asked of a pane or file tab whose bar is down.
  case noFindBar(id: UUID)
  /// A find with nothing to find: a pane's engine takes empty text as the end.
  case noFindText(id: UUID)
  /// A worktree with no tabs, so no groups to size.
  case noGroups(id: String)
  /// A key the helper would have refused, from a client that did not ask it.
  case noKey(name: String)
  case noMenuItem(path: String)
  case noPane(id: UUID)
  case noProject(id: String)
  /// No pull request or CI run to show for the worktree, so no popover.
  case noServices(id: String)
  case noSetting(key: String)
  /// The tab's pane tree has no split at that path.
  case noSplit(id: UUID, path: [Int])
  /// The quick switcher lists no row to choose.
  case noSwitcherRow
  case noTab(id: UUID)
  /// No worktree's tabs are on screen: none selected, or a cover over them.
  case nothingInView
  /// No alert, dialog, sheet or field is up to dismiss.
  case nothingPresented
  /// The main window is closed, so there is nothing to size or draw.
  case noWindow
  case noWorktree(id: String)
  /// Move Tab to New Group on a group's only tab, which has no group to leave.
  case onlyTabInGroup(id: UUID)
  /// Its shell has not started: its worktree has never been shown.
  case paneNotLive(id: UUID)
  /// A project moved beside itself, which moves nothing.
  case projectBesideItself(id: String)
  /// The project's folder is gone, so git listed nothing.
  case projectFolderMissing(id: String)
  /// Add Project took the path but no project holds it, and raised no alert.
  case projectNotAdded(path: String)
  /// A project row chosen whose project has no worktree to show.
  case projectWithNoWorktree(id: String)
  /// The quick switcher went down while the request waited on it.
  case quickSwitcherClosed
  /// The pre-delete hook refused, in its own words; the worktree stays.
  case removalVetoed(id: String, message: String)
  /// The app did what was asked but could not write its answer down.
  case replyNotEncoded
  /// Off screen, or not yet drawn, so there is nothing to capture.
  case screenshotFailed
  /// `debug services stand-in` was given JSON it cannot read: where, and why.
  case serviceStandInUnreadable(reason: String)
  /// A share leaving a pane or group narrower than a drag would, in points.
  case shareBelowMinimum(points: Double)
  /// A step asked while the tab's view has yet to take the one before it.
  case stepNotYetTaken(id: UUID)
  /// The row chosen leads to a worktree, tab or pane gone since it was listed.
  case switcherRowGone
  /// A tab moved onto the worktree it is already in.
  case tabAlreadyThere(id: UUID)
  /// A tab moves only beside another of its own worktree's.
  case tabInAnotherWorktree(id: UUID)
  /// The store refused the move with the tab and its group still there.
  case tabNotMoved(id: UUID)
  /// Not in front in its group, or its worktree out of view: what a file tab's
  /// bar does needs its view.
  case tabNotShown(id: UUID)
  /// A file tab, which keeps its file's name and has no panes.
  case tabShowsAFile(id: UUID)
  /// A terminal tab, which has no file's bar to step or find in.
  case tabShowsNoFile(id: UUID)
  /// A panel width a drag could not reach, in points.
  case widthOutOfRange(minimum: Double, maximum: Double)
  /// Sized there, the window shrinks inside the full-screen space.
  case windowInFullScreen
  /// The create ended with no worktree and no alert, as a Cancel does.
  case worktreeNotCreated
  /// The worktree is being created or removed, or its directory is gone.
  case worktreeNotReady(id: String)
  /// The main checkout or a bare repository, which only removing the
  /// project takes away.
  case worktreeNotRemovable(id: String)
  /// The removal ended with the worktree still listed and no alert.
  case worktreeNotRemoved(id: String)
  /// A share count other than the split's or the worktree's groups'.
  case wrongShareCount(expected: Int)
}
