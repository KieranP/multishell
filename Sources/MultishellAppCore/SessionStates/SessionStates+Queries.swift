import Foundation
import MultishellCore

extension SessionStates {
  subscript(key: Key) -> SessionState? { entries[key]?.state }

  func since(_ key: Key) -> Date? { entries[key]?.since }
  func note(_ key: Key) -> SessionNote? { entries[key]?.note }

  /// The workers out under one key, oldest first.
  func subagents(_ key: Key) -> [Subagent] { entries[key]?.roster.subagents ?? [] }

  /// The ends a shell's exit stands for, one per key it is out under.
  func endings(ofShell pid: Int32) -> [(key: Key, report: SubagentReport)] {
    entries.flatMap { key, entry in
      entry.roster.subagents.filter { $0.pid == pid }.map {
        (key: key, report: SubagentReport(id: $0.id, phase: .ended))
      }
    }
  }

  /// The agents' own pids and their background shells'.
  var trackedPIDs: Set<Int32> {
    Set(entries.values.flatMap { [$0.pid] + $0.roster.subagents.map(\.pid) }.compactMap { $0 })
  }

  func state(ofSessions ids: [TerminalSession.ID]) -> SessionState? {
    SessionState.mostUrgent(ids.compactMap { self[.session($0)] })
  }

  func state(ofWorktree id: Worktree.ID, sessions: [TerminalSession.ID]) -> SessionState? {
    var candidates = sessions.compactMap { self[.session($0)] }
    if let own = self[.worktree(id)] { candidates.append(own) }
    return SessionState.mostUrgent(candidates)
  }

  /// Panes showing Working, whoever reported it.
  var workingSessionIDs: [TerminalSession.ID] {
    entries.compactMap { key, entry in
      guard case .session(let id) = key, entry.state == .running else { return nil }
      return id
    }
  }

  /// Whether an agent reported Working here. The shell's own Working is its
  /// command's, an agent's only where `commandIsAgent`: one typed with no hooks.
  func isAgentWorking(in id: TerminalSession.ID, commandIsAgent: Bool) -> Bool {
    guard let entry = entries[.session(id)], entry.state == .running else { return false }
    return !entry.workingIsShellCommand || commandIsAgent
  }

  /// Nothing showing and nothing out. A stamp and a note outlive the state
  /// they were about, so neither counts; a roster does.
  var isEmpty: Bool {
    !entries.values.contains { $0.state != nil || !$0.roster.subagents.isEmpty }
  }
}
