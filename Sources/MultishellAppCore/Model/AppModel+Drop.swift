import Foundation
import MultishellCore

// MARK: - Files dropped on a terminal

extension AppModel {
  /// Files dropped on a session's surface, pasted in as the text `FileDrop`
  /// decides: paths for a shell, mentions for an agent that reads them. The
  /// pane takes focus with them, since what was dropped is there to be
  /// typed at.
  ///
  /// `false` when nothing was pasted, so the drag says so rather than the
  /// app swallowing the files: a saved tab whose shell has not started has
  /// no prompt to paste at, and a file name a terminal cannot be told
  /// safely is left out by `FileDrop`.
  @discardableResult
  public func dropFiles(_ urls: [URL], into id: TerminalSession.ID) -> Bool {
    guard acceptsFileDrop(into: id), let session = workspace.session(id) else { return false }
    let text = FileDrop.text(
      for: urls,
      relativeTo: session.workingDirectory,
      mentionPrefix: fileMentionPrefix(for: session)
    )
    guard !text.isEmpty, host.paste(text, into: id) else { return false }
    // The pane the files landed in is the one being worked in now. Recorded
    // as well as focused: only an engine that reports focus back would
    // otherwise move the tab's focused pane.
    store.focusSession(id)
    host.focus(id)
    return true
  }

  /// Whether a drag over a pane should offer to drop: a shell has to be
  /// running in it.
  public func acceptsFileDrop(into id: TerminalSession.ID) -> Bool {
    liveSessions.contains(id)
  }

  /// How the agent at a pane's prompt is told about a file, if it is told
  /// at all. A plain shell, a custom command and an agent the catalogue
  /// gives no prefix all get a quoted path.
  private func fileMentionPrefix(for session: TerminalSession) -> String? {
    agentAtThePrompt(of: session).flatMap { AgentCatalogue.agent($0)?.fileMentionPrefix }
  }

  /// Which agent a pane holds: the one that reported there while its
  /// process is up, else the one the tab was opened for. The report is the
  /// better answer and usually the only one — an agent typed at a shell
  /// prompt is how most panes get theirs, and it says so through its hooks
  /// the moment it starts.
  public func agentAtThePrompt(of session: TerminalSession) -> String? {
    if let reported = reportedAgents[session.id], reported.isAtThePrompt {
      return reported.agentID
    }
    return session.agentID
  }
}
