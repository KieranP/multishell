import Foundation
import MultishellCore

extension AppModel {
  /// What the shell says it started, while it runs. An agent naming itself
  /// is left alone; see Docs/design/agents.md.
  private func noteCommandAgent(_ report: SessionStateReport, of id: TerminalSession.ID) {
    guard report.isFromShellIntegration == true, report.agentID == nil else { return }
    setIfChanged(
      \.commandAgentIDs[id], report.command.flatMap { AgentCatalogue.agent(runningCommand: $0)?.id }
    )
  }

  /// A report names a live session, or only a directory. One naming an
  /// unknown session is dropped, never matched by directory.
  func receive(_ report: SessionStateReport) {
    if debugToolsEnabled { stateReportsSinceDebugSample += 1 }
    // An older helper's walk from a prompt ends at this process, whose pid
    // never goes while it is looking; see Docs/design/agents.md.
    let pid = report.pid == ProcessInfo.processInfo.processIdentifier ? nil : report.pid
    // A shell's exit can wake the agent before the poll sees it go, where no
    // list of what is out says so; see Docs/design/agents.md.
    if report.state == .done, report.resumesAfterWorkers == true, report.workersOut == nil {
      sweepGonePIDs()
    }
    if let id = report.sessionID {
      guard liveSessionIDs.contains(id), workspace.session(id) != nil else { return }
      // Who is at that prompt, so a drop is written as that agent reads a file.
      if let agent = report.agentID {
        setIfChanged(\.reportedAgents[id], ReportedAgent(agentID: agent, pid: pid))
      }
      noteCommandAgent(report, of: id)
      apply(report, pid: pid, to: .session(id))
    } else if let workingDirectory = report.workingDirectory,
      let worktree = worktree(atPath: workingDirectory)
    {
      apply(report, pid: pid, to: .worktree(worktree.id))
    }
    updatePIDWatch()
  }

  private func visibility(of key: SessionStates.Key) -> SessionVisibility? {
    switch key {
    case .session(let id):
      guard let session = workspace.session(id) else { return nil }
      return SessionVisibility(
        worktreeID: session.worktreeID, isSeen: isSeen(id),
        isOnScreen: isPaneInView(id) && platform.isActive)
    case .worktree(let id):
      // Gated on the board as `isPaneInView` is, the worktree being selected
      // with nothing of it on screen; and on frontmost as `isSeen`.
      let seen = worktreeIDInView == id && platform.isActive
      return SessionVisibility(worktreeID: id, isSeen: seen, isOnScreen: seen)
    }
  }

  func apply(_ report: SessionStateReport, pid: Int32?, to key: SessionStates.Key) {
    guard let visibility = visibility(of: key) else { return }
    var meant: SessionState?
    mutateStates {
      meant = $0.report(report, pid: pid, for: key, isSeen: visibility.isSeen)
    }
    if let meant {
      notifyIfNeeded(
        report, as: meant, key: key, worktreeID: visibility.worktreeID,
        isOnScreen: visibility.isOnScreen)
    }
  }
}
