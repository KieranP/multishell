import Foundation
import MultishellCore

extension AppModel {
  /// Activity in the pane with the keyboard is being watched; anywhere else,
  /// a split's other pane included, it is remembered until that pane is focused.
  func noteActivity(in id: TerminalSession.ID) {
    // A prompt or a finished command in this worktree likely changed its
    // status, so look soon rather than waiting for the next poll.
    if let session = workspace.session(id) {
      scheduleStatusRefresh(of: session.worktreeID)
    }
    noteStateActivity(in: id)
  }

  private func noteStateActivity(in id: TerminalSession.ID) {
    mutateStates { $0.noteActivity(in: id, isSeen: hasBeenSeen(id)) }
  }

  /// A retitle is activity for the pane's dot. It reads git only in a plain
  /// shell that reports no finished command; see worktrees.md.
  func noteTitle(_ title: String, of id: TerminalSession.ID) {
    setIfChanged(\.sessionTitles[id], title)
    if let session = workspace.session(id), !isAgentPane(session),
      !ShellLaunch.reportsFinishedCommands(shellPath(forWorktree: session.worktreeID))
    {
      scheduleStatusRefresh(of: session.worktreeID)
    }
    noteStateActivity(in: id)
  }

  /// What the tab strip shows: the user's name, else what the shell last
  /// reported, else the tab's starting title.
  public func title(of tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[tab.focusedSessionID] ?? workspace.title(of: tab)
  }

  /// One pane's, a split holding several: the user's name for the tab, else
  /// what this pane's shell last reported, else its starting title.
  public func title(ofPane session: TerminalSession, in tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[session.id] ?? session.displayTitle
  }
}
