import Foundation
import MultishellCore

extension AppModel {
  /// Files dropped on a surface, pasted as `FilePathText` decides and taking
  /// the focus. `false` when nothing was pasted, so the drag says so.
  @discardableResult
  public func dropFiles(
    _ urls: [URL],
    into id: TerminalSession.ID,
    takingFocus: Bool,
  ) -> Bool {
    guard acceptsFileDrop(into: id), workspace.session(id) != nil,
      let text = pastedText(for: urls, into: id), host.paste(text + " ", into: id)
    else { return false }
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
    liveSessionIDs.contains(id)
  }

  /// What a paste of copied files types in a session, worded as a drop on it
  /// would be, or as a shell takes them where the session is gone.
  func pastedText(for urls: [URL], into id: TerminalSession.ID) -> String? {
    let session = workspace.session(id)
    // Asked once: each ask probes the reporting pid, and two could disagree.
    let agentID = session.flatMap(agentIDAtThePrompt(of:))
    return FilePathText.pastedText(
      for: urls,
      relativeTo: session.map { mentionDirectory(for: $0, agentID: agentID) },
      mentionPrefix: agentID.flatMap { AgentCatalogue.agent($0)?.fileMentionPrefix },
    )
  }

  /// Where the agent at the prompt said it runs, else where the pane started.
  private func mentionDirectory(for session: TerminalSession, agentID: String?) -> URL {
    guard let agentID, reportedAgents[session.id]?.agentID == agentID,
      let directory = reportedAgentDirectories[session.id]
    else { return session.workingDirectory }
    return directory
  }
}
