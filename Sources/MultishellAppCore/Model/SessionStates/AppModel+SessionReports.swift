import Foundation
import MultishellCore

extension AppModel {
  /// What the shell says it started, while it runs. An agent naming itself
  /// is left alone; see Docs/design/agents/board-and-pane-rows.md.
  private func noteCommandAgent(_ report: SessionStateReport, of id: TerminalSession.ID) {
    guard report.isFromShellIntegration == true, report.agentID == nil else { return }
    setIfChanged(
      \.commandAgentIDs[id],
      report.command.flatMap { AgentCatalogue.agent(runningCommand: $0)?.id },
    )
  }

  /// A report names a live session, or only a directory. One naming an
  /// unknown session is dropped, never matched by directory.
  func receive(_ report: SessionStateReport) {
    if areDebugToolsEnabled { debugSampler.stateReportCount += 1 }
    // An older helper's walk from a prompt ends at this process, whose pid
    // never goes while it is looking; see Docs/design/agents/reports-and-hooks.md.
    let pid = report.pid == ProcessInfo.processInfo.processIdentifier ? nil : report.pid
    // A shell's exit can wake the agent before the poll sees it go, where no
    // list of what is out says so; see Docs/design/agents/background-work.md.
    if report.state == .done, report.resumesAfterWorkers == true, report.workersOut == nil {
      sweepGonePIDs()
    }
    if let id = report.sessionID {
      guard liveSessionIDs.contains(id), workspace.session(id) != nil else { return }
      // Who is at that prompt, so a drop is written as that agent reads a file;
      // an agent a holding program ran from its tool shell is not.
      if let agentID = report.agentID,
        !sessionStates.isNestedAgent(agentID, on: .session(id))
      {
        noteReportedAgent(
          agentID,
          pid: pid,
          directory: report.workingDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) },
          in: id,
        )
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
        worktreeID: session.worktreeID,
        isSeen: isSeen(id),
        isOnScreen: isPaneInView(id) && platform.isActive,
      )

    case .worktree(let id):
      let seen = isWorktreeOnScreen(id)
      return SessionVisibility(worktreeID: id, isSeen: seen, isOnScreen: seen)
    }
  }

  func apply(_ report: SessionStateReport, pid: Int32?, to key: SessionStates.Key) {
    applyAndNotify(to: key, isSilent: report.isSilent == true) { states, isSeen in
      states.apply(report, pid: pid, for: key, isSeen: isSeen)
    }
  }

  /// A change to one key's state, and a banner where what it meant calls for
  /// one; `change` returns that, `nil` for no news.
  func applyAndNotify(
    to key: SessionStates.Key,
    isSilent: Bool,
    _ change: (inout SessionStates, _ isSeen: Bool) -> SessionNote?,
  ) {
    guard let visibility = visibility(of: key) else { return }
    var note: SessionNote?
    mutateStates { note = change(&$0, visibility.isSeen) }
    if let note {
      notifyIfNeeded(
        note,
        isSilent: isSilent,
        key: key,
        worktreeID: visibility.worktreeID,
        isOnScreen: visibility.isOnScreen,
      )
    }
  }
}
