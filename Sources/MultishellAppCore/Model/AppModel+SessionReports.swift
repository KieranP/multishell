import Foundation
import MultishellCore
import MultishellProcess

extension AppModel {
  /// Opens the inbound channel. `false` where another copy of this build
  /// holds it: this one hands over to it and quits; see state-and-store.md.
  func startStateSource() -> Bool {
    do {
      try stateSource.start()
      return true
    } catch let failure as SocketFailure where failure.kind == .inUse {
      yieldingToRunningInstance = true
      pendingSave?.cancel()
      platform.handOverToRunningInstance()
      // Still here: the platform could not quit, so say what is wrong.
      report(failure)
      return false
    } catch {
      report(error)
      return true
    }
  }

  /// On quit: the last save, and the socket file unlinked so the next
  /// launch does not have to probe it.
  public func shutDown() {
    saveNow()
    stateSource.stop()
    host.shutDown()
  }

  /// What the shell says it started, while it runs. An agent naming itself
  /// is left alone; see Docs/design/agents.md.
  private func noteCommandAgent(_ report: SessionStateReport, of id: TerminalSession.ID) {
    guard report.isShell == true, report.agent == nil else { return }
    setIfChanged(
      \.commandAgents[id], report.command.flatMap { AgentCatalogue.agent(runningCommand: $0)?.id })
  }

  /// A report names a live session, or only a directory. One naming an
  /// unknown session is dropped, never matched by directory.
  func apply(_ report: SessionStateReport) {
    // An older helper's walk from a prompt ends at this process, whose pid
    // never goes while it is looking; see Docs/design/agents.md.
    let pid = report.pid == ProcessInfo.processInfo.processIdentifier ? nil : report.pid
    if let id = report.sessionID {
      guard liveSessions.contains(id), workspace.session(id) != nil else { return }
      // Who is at that prompt, so a drop is written as that agent reads a file.
      if let agent = report.agent {
        setIfChanged(\.reportedAgents[id], ReportedAgent(agentID: agent, pid: pid))
      }
      noteCommandAgent(report, of: id)
      apply(report, pid: pid, to: .session(id))
    } else if let cwd = report.cwd, let worktree = worktree(atPath: cwd) {
      apply(report, pid: pid, to: .worktree(worktree.id))
    }
    updatePIDWatch()
  }

  /// `isSeen` is the focused pane and clears a Done; `isOnScreen` is any pane
  /// in view and holds the banner. See Docs/design/terminals.md.
  private struct Visibility {
    var worktreeID: Worktree.ID
    var isSeen: Bool
    var isOnScreen: Bool
  }

  private func visibility(of key: SessionStates.Key) -> Visibility? {
    switch key {
    case .session(let id):
      guard let session = workspace.session(id) else { return nil }
      return Visibility(
        worktreeID: session.worktreeID, isSeen: hasBeenSeen(id),
        isOnScreen: isShown(id) && platform.isActive)
    case .worktree(let id):
      // Gated on the board as `isShown` is, the worktree being selected
      // with nothing of it on screen; and on frontmost as `hasBeenSeen`.
      let seen = !showsAgentBoard && workspace.selectedWorktreeID == id && platform.isActive
      return Visibility(worktreeID: id, isSeen: seen, isOnScreen: seen)
    }
  }

  func apply(_ report: SessionStateReport, pid: Int32?, to key: SessionStates.Key) {
    guard let visibility = visibility(of: key) else { return }
    var meant: SessionState?
    mutateStates {
      meant = $0.report(
        report.state, pid: pid, message: report.message, duration: report.duration,
        subagent: report.subagentChange, startsTurn: report.startsTurn == true,
        startsSession: report.startsSession == true,
        backgroundShells: report.backgroundShells ?? [], fromShell: report.isShell == true,
        resumesAfterWorkers: report.resumesAfterWorkers == true,
        conversationID: report.conversationID, for: key, isSeen: visibility.isSeen)
    }
    if let meant {
      notifyIfNeeded(
        report, as: meant, key: key, worktreeID: visibility.worktreeID,
        isOnScreen: visibility.isOnScreen)
    }
  }

  /// Pays the awaited Done if the agent reports nothing within `resumeGrace`.
  func scheduleResumeDeadline(for key: SessionStates.Key) {
    resumeDeadlines[key]?.cancel()
    resumeDeadlines[key] = Task { @MainActor [weak self, resumeGrace] in
      try? await Task.sleep(for: resumeGrace)
      guard !Task.isCancelled, let self else { return }
      resumeDeadlines[key] = nil
      payOverdueResume(key)
    }
  }

  private func payOverdueResume(_ key: SessionStates.Key) {
    guard let visibility = visibility(of: key) else { return }
    var meant: SessionState?
    mutateStates { meant = $0.payOverdueResume(key, isSeen: visibility.isSeen) }
    if let meant {
      notifyIfNeeded(
        SessionStateReport(state: meant), as: meant, key: key, worktreeID: visibility.worktreeID,
        isOnScreen: visibility.isOnScreen)
    }
  }
}
