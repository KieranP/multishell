import Foundation
import MultishellCore

extension AppModel {
  /// The user's name, else what the shell last reported, else the tab's
  /// starting title. The command line reads this one, raw.
  func title(of tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[tab.focusedSessionID] ?? workspace.title(of: tab)
  }

  /// A file tab's: its name, lengthened where another open file shares it.
  public func title(of tab: FileTab) -> String {
    workspace.title(of: tab)
  }

  /// One pane's, a split holding several: the user's name for the tab, else
  /// what this pane's shell last reported, else its starting title. Raw too.
  func title(ofPane session: TerminalSession, in tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[session.id] ?? session.displayTitle
  }

  /// `title(of:)` as the strip and Debug Info draw it.
  public func shownTitle(of tab: TerminalTab) -> String {
    guard tab.customTitle == nil, let reported = sessionTitles[tab.focusedSessionID] else {
      return title(of: tab)
    }
    return shown(reported, worktreePath: workspace.worktree(tab.worktreeID)?.path.path)
  }

  /// `title(ofPane:in:)` as the sidebar, the board, the switcher and a banner
  /// draw it, each already holding the tab's worktree.
  func shownTitle(
    ofPane session: TerminalSession,
    in tab: TerminalTab,
    of worktree: Worktree,
  ) -> String {
    guard tab.customTitle == nil, let reported = sessionTitles[session.id] else {
      return title(ofPane: session, in: tab)
    }
    return shown(reported, worktreePath: worktree.path.path)
  }

  private func shown(_ reported: String, worktreePath: String?) -> String {
    ShownPaneTitle.shown(reported, worktreePath: worktreePath, home: ShownPaneTitle.accountHome)
  }
}
