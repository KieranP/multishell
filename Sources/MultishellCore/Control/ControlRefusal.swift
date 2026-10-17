import Foundation

/// Why the app did not do what a request asked. Data, not words: the
/// helper says each in English, as its output stays (translation.md).
public enum ControlRefusal: Error, Codable, Equatable, Sendable {
  /// Not on the login shell's PATH, so the tab would open as a plain shell.
  case agentNotInstalled(id: String)
  case agentWorking
  /// The app raised an alert instead; its words, in the app's language.
  case alert(title: String, message: String)
  case debugToolsOff
  case invalidBranchName(String)
  case invalidValue(key: String, value: String)
  /// Greyed out in the menu now, as a click would find it.
  case menuItemDisabled(path: String)
  /// No catalogue agent has the id.
  case noAgent(id: String)
  case noAgentChosen
  /// A find step asked of a pane whose bar is down.
  case noFindBar(id: UUID)
  /// A find with nothing to find: the engine takes empty text as the end.
  case noFindText(id: UUID)
  /// A key the helper would have refused, from a client that did not ask it.
  case noKey(name: String)
  case noMenuItem(path: String)
  case noPane(id: UUID)
  case noProject(id: String)
  case noSetting(key: String)
  case noTab(id: UUID)
  /// No worktree's tabs are on screen: none selected, or a cover over them.
  case nothingInView
  /// No alert, dialog, sheet or field is up to dismiss.
  case nothingPresented
  /// The main window is closed, so there is nothing to size or draw.
  case noWindow
  case noWorktree(id: String)
  /// Its shell has not started: its worktree has never been shown.
  case paneNotLive(id: UUID)
  /// Add Project took the path but no project holds it, and raised no alert.
  case projectNotAdded(path: String)
  /// The pre-delete hook refused, in its own words; the worktree stays.
  case removalVetoed(id: String, message: String)
  /// The app did what was asked but could not write its answer down.
  case replyNotEncoded
  /// Off screen, or not yet drawn, so there is nothing to capture.
  case screenshotFailed
  /// A tab moves only beside another of its own worktree's.
  case tabInAnotherWorktree(id: UUID)
  /// A file tab, which keeps its file's name and has no panes.
  case tabShowsAFile(id: UUID)
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
}
