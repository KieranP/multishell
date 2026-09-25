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

  func noteCommandFinished(in id: TerminalSession.ID, exitCode: Int32?) {
    if let session = workspace.session(id) {
      scheduleStatusRefresh(of: session.worktreeID)
    }
    // An agent typed at the prompt was the foreground command, so the pane is
    // a plain shell again; with the board closed no pid poll would say so.
    setIfChanged(\.reportedAgents[id], nil)
    mutateStates { $0.noteCommandFinished(in: id, exitCode: exitCode, isSeen: hasBeenSeen(id)) }
    updateDockBadge()
    updatePIDWatch()
  }
}
