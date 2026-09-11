import Foundation
import MultishellCore

// MARK: - Files dropped on a terminal

extension AppModel {
  /// Files dropped on a surface, pasted as `FileDrop` decides and taking the
  /// focus. `false` when nothing was pasted, so the drag says so.
  @discardableResult
  public func dropFiles(
    _ urls: [URL], into id: TerminalSession.ID, takingFocus: Bool = true
  ) -> Bool {
    guard acceptsFileDrop(into: id), let session = workspace.session(id) else { return false }
    let text = FileDrop.text(
      for: urls,
      relativeTo: session.workingDirectory,
      mentionPrefix: fileMentionPrefix(for: session)
    )
    guard !text.isEmpty, host.paste(text, into: id) else { return false }
    // Recorded as well as focused, only a reporting engine moving the tab's
    // focused pane otherwise. Not once the pane has left the screen.
    if takingFocus {
      store.focusSession(id)
      host.focus(id)
    }
    return true
  }

  /// Whether a drag over a pane should offer to drop: a shell has to be
  /// running in it.
  public func acceptsFileDrop(into id: TerminalSession.ID) -> Bool {
    liveSessions.contains(id)
  }

  /// How the agent at a pane's prompt is told about a file. A shell, a custom
  /// command and an agent with no prefix all get a quoted path.
  private func fileMentionPrefix(for session: TerminalSession) -> String? {
    agentAtThePrompt(of: session).flatMap { AgentCatalogue.agent($0)?.fileMentionPrefix }
  }

  /// Which agent a pane holds: the one that reported while its process is up,
  /// else the tab's own. Most panes get theirs typed at a shell prompt.
  public func agentAtThePrompt(of session: TerminalSession) -> String? {
    if let reported = reportedAgents[session.id], reported.isAtThePrompt {
      return reported.agentID
    }
    return session.agentID
  }
}
