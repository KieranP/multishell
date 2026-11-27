import Foundation
import MultishellCore
import MultishellGitKit

/// Send Conflicts To, and the tab a project sending them unasked opens; the
/// handoff the PR and CI pages use (services/send-feedback.md).
extension AppModel {
  /// A mention of the file pasted into that agent's prompt, Return left to the
  /// user, and the pane brought on screen.
  public func sendConflicts(of worktree: Worktree, to sessionID: TerminalSession.ID) async {
    guard let conflicts = await conflictsToSend(of: worktree),
      let recipient = handoffRecipient(id: sessionID, in: worktree.id)
    else { return }
    let delivery = deliverHandoff(
      ConflictHandoff.document(method: conflicts.method, paths: conflicts.paths),
      named: ConflictHandoff.fileName(forWorktreeNamed: conflicts.worktreeName),
      sentence: ConflictHandoff.sentence(mentioning:),
      to: recipient,
      takingFocus: false,
    )
    switch delivery {
    case .delivered:
      reveal(pane: recipient.id)

    case .notPasted:
      presentedError = .conflictsNotPasted(to: recipient.agentName)

    case .notWritten:
      break
    }
  }

  /// The submenu's New Agent Tab: the project's agent started on them, its
  /// worktree selected.
  public func sendConflictsToNewAgentTab(of worktree: Worktree) async {
    guard let conflicts = await conflictsToSend(of: worktree) else { return }
    openConflictTab(
      in: worktree,
      named: conflicts.worktreeName,
      method: conflicts.method,
      paths: conflicts.paths,
      selecting: true,
    )
  }

  /// A new tab running the preferred agent on the file, never the worktree's own agent
  /// tab. Its worktree is selected only where `selecting`; out of view, it starts there.
  @discardableResult
  func openConflictTab(
    in worktree: Worktree,
    named worktreeName: String,
    method: UpdateMethod,
    paths: [String],
    selecting: Bool,
  ) -> TerminalSession.ID? {
    guard let agentID = effectiveAgentID(for: worktree) else {
      presentedError = .noAgentChosen
      return nil
    }
    let file: URL
    do {
      file = try AgentHandoff.write(
        ConflictHandoff.document(method: method, paths: paths),
        named: ConflictHandoff.fileName(forWorktreeNamed: worktreeName),
        in: dropsDirectory,
      )
    } catch {
      present(error)
      return nil
    }
    let mention =
      handoffMention(of: file, prefixed: fileMentionPrefix(ofAgent: agentID), sentence: { $0 })
      ?? file.path
    let prompt = ConflictHandoff.prompt(mentioning: mention, method: method)
    var opened: TerminalTab?
    if selecting {
      select(worktree, openingFirstTab: .never) {
        guard isShellReadyBesidesDirectory(worktree) else { return }
        opened = addAgentTab(agentID, in: worktree, group: nil, task: prompt)
      }
    } else if requireShellReady(worktree) {
      opened = addAgentTab(agentID, in: worktree, group: nil, task: prompt)
      warmWorktrees.insert(worktree.id)
      reconcileSessions(takingFocus: isInView(worktree))
    }
    guard let opened else {
      AgentHandoff.discard(file)
      return nil
    }
    return opened.focusedSessionID
  }

  /// The stop, its unmerged paths and the name to file them under, read afresh as the
  /// row is a poll behind. `nil` where nothing is unmerged, the row then read again.
  private func conflictsToSend(
    of worktree: Worktree
  ) async -> (method: UpdateMethod, paths: [String], worktreeName: String)? {
    guard let git = coordinator?.git else { return nil }
    guard let method = await git.unfinishedUpdate(in: worktree.path) else {
      await refreshAfterBaseUpdate(of: worktree)
      return nil
    }
    do {
      let paths = try await git.conflictedPaths(in: worktree)
      guard !paths.isEmpty else {
        await refreshAfterBaseUpdate(of: worktree)
        return nil
      }
      return (method, paths, await displayNameWhileUnfinished(of: worktree, using: git))
    } catch {
      if workspace.worktree(worktree.id) != nil { present(error) }
      return nil
    }
  }
}
