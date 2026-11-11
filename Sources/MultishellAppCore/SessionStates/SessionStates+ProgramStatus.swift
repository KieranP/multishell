import Foundation
import MultishellCore

/// A program's own OSC 7501 report read into its pane's entry. See
/// Docs/design/agents/program-status.md.
extension SessionStates {
  /// Returns what the pane moved to, `nil` where the dot stands: a report
  /// that only reworded the same state is no news.
  @discardableResult
  mutating func apply(
    programStatus status: ProgramStatus,
    pid: Int32?,
    for key: Key,
    isSeen: Bool,
    at now: Date,
  ) -> SessionNote? {
    let recordsBefore = entries[key]?.programRecords ?? ProgramStatusRecords()
    if status.recordID == nil, status.state == .clear {
      // The program's own clear at its exit is the program gone; with no hold,
      // a full reset's clear moves nothing.
      if recordsBefore.isHolding { dropProcessClaims(on: key) }
      return nil
    }
    let commandStart = entries[key].flatMap { entry in
      entry.state == .running && entry.workingIsShellCommand ? entry.since : nil
    }
    update(key) { stored in
      let hooks = stored.agentReportedByHooks
      // The hooks' pid stands for a report naming none only where they name its
      // agent: a child's `app` names nothing, so a child's agent is the hold's.
      let ownAgent =
        status.recordID == nil ? status.app.flatMap(AgentCatalogue.agent(reportingStatusAs:)) : nil
      let reportAgentID = (ownAgent ?? stored.programRecords.agent)?.id
      let hooksPID = reportAgentID == nil || reportAgentID == hooks?.agentID ? hooks?.pid : nil
      stored.programRecords.record(status, from: pid ?? hooksPID, at: now)
      // A new hold: what an earlier one announced is spent, the agent its hooks
      // named is the one it is, and its work began with the shell's command.
      guard !recordsBefore.isHolding, stored.programRecords.isHolding else { return }
      stored.forgetAnnouncedFinish()
      if let hooks { stored.programRecords.adoptAgent(hooks.agentID, pid: hooks.pid) }
      if let commandStart { stored.programRecords.backdateWork(to: commandStart) }
    }
    // A stray child's finish where no program holds moves nothing.
    guard isHeldByProgram(key), let entry = entries[key] else { return nil }
    let records = entry.programRecords
    let shown = records.shownState
    guard !recordsBefore.isHolding || shown != recordsBefore.shownState else { return nil }
    let state = entry.programShownState
    if state == .running, entry.state == .running { return nil }
    switch state {
    case .idle:
      update(key) { stored in
        stored.state = nil
        stored.pid = nil
      }

    case .done, .failed:
      landFinished(state, on: key, isSeen: isSeen)

    case .running, .attention:
      landUnderway(state, pid: records.pid ?? pid, on: key)
    }
    update(key) { $0.programFinishShown = state.isFinished ? state : nil }
    // A command's finish is timed as the shell's is; an agent's turn, as its
    // hooks' never were, is not.
    let isCommand = entry.programAgent == nil
    let duration = state.isFinished && isCommand ? records.duration(endingAt: now) : nil
    let note = SessionNote(
      state: state,
      // A Done held over workers says its words when it lands, not before.
      message: state == shown ? records.shownMessage(movedBy: status, isAgent: !isCommand) : nil,
      duration: duration,
    )
    noteIfStanding(note, on: key)
    return note
  }

  /// The program has left the front with its records. A finish it announced
  /// is remembered for the command's end, and for the shell's report to come.
  mutating func endProgramHold(on key: Key) {
    update(key) { stored in
      if stored.programRecords.isHolding, let shown = stored.programFinishShown {
        stored.finishAnnouncedForCommandEnd = shown
        stored.finishAnnouncedForShellReport = shown
      }
      stored.forgetProgramHold()
    }
  }

  /// A report read against the program holding the pane before the hooks
  /// read it. Returns whether it is spent: a nested agent's, or a repeat.
  mutating func spendOnProgramHold(_ report: SessionStateReport, pid: Int32?, on key: Key) -> Bool {
    if report.isFromShellIntegration == true {
      let isRepeat = repeatsAnnouncedFinish(report, on: key)
      releaseProgramHold(atShellReport: report, on: key)
      return isRepeat
    }
    if isNestedAgent(report.agentID, on: key) { return true }
    noteAgentNamedByHook(report, pid: pid, on: key)
    return false
  }

  /// The agent a hook names in a pane: kept for a hold that begins, and taken
  /// by one under way that has none. No pid keeps the one it gave.
  private mutating func noteAgentNamedByHook(
    _ report: SessionStateReport,
    pid: Int32?,
    on key: Key,
  ) {
    guard case .session = key, let agentID = report.agentID else { return }
    update(key) { stored in
      stored.agentReportedByHooks = .reported(
        agentID,
        pid: pid,
        after: stored.agentReportedByHooks,
      )
      if stored.programRecords.isHolding { stored.programRecords.adoptAgent(agentID, pid: pid) }
    }
  }

  /// Whether the shell's report repeats the finish the program announced as
  /// its hold ended, or announces as the report ends it, which is no news.
  private func repeatsAnnouncedFinish(_ report: SessionStateReport, on key: Key) -> Bool {
    guard let entry = entries[key] else { return false }
    let holding = entry.programRecords.isHolding ? entry.programFinishShown : nil
    guard let announced = entry.finishAnnouncedForShellReport ?? holding else { return false }
    return report.state.repeatsFinish(announced: announced)
  }

  /// The shell's own report: the program is no longer in front, and neither is
  /// the agent its hooks named. A command starting spends the last one's end.
  private mutating func releaseProgramHold(atShellReport report: SessionStateReport, on key: Key) {
    endProgramHold(on: key)
    update(key) { stored in
      stored.finishAnnouncedForShellReport = nil
      if report.state == .running { stored.finishAnnouncedForCommandEnd = nil }
    }
  }

  /// Whether a hook says nothing new after the program left on a finish: its
  /// Idle, as Claude's session end after its clear, or a late Stop repeating it.
  func isHookRepeatingAnnouncedFinish(_ report: SessionStateReport, on key: Key) -> Bool {
    guard let entry = entries[key],
      let announced = entry.finishAnnouncedForCommandEnd ?? entry.finishAnnouncedForShellReport
    else { return false }
    return report.state == .idle || report.state.repeatsFinish(announced: announced)
  }

  /// Work starting after the program left: what it announced is past.
  mutating func forgetAnnouncedFinish(on key: Key) {
    update(key) { $0.forgetAnnouncedFinish() }
  }

  /// The roster's turn as the agent's hooks tell it: a Stop vouches for the workers out,
  /// and an Idle or a failure ends them all. A worker's report says nothing of the turn.
  mutating func keepTurnUnderProgramHold(
    _ state: SessionState,
    worker: WorkerReport?,
    on key: Key,
  ) {
    guard worker == nil else { return }
    switch state {
    case .done: update(key) { $0.roster.markOutAtStop() }
    case .idle, .failed: update(key) { $0.settleTurn() }
    case .running, .attention: break
    }
  }

  /// Under a program's hold a hook's worker moves the dot only over the
  /// program's Done; see agents/program-status.md.
  mutating func applyWorkerToProgramHold(
    _ worker: WorkerReport?,
    on key: Key,
    isSeen: Bool,
  ) -> SessionNote? {
    if let worker { update(key) { $0.record(worker) } }
    guard let entry = entries[key], entry.programRecords.shownState == .done else { return nil }
    if entry.roster.hasWorkOut {
      guard entry.programFinishShown == .done else { return nil }
      update(key) { stored in
        stored.state = .running
        stored.programFinishShown = nil
      }
      return SessionNote(state: .running)
    }
    let wakesProgram = worker?.phase == .ended && worker?.wakesAgent != false
    guard entry.state == .running, !(wakesProgram && entry.resumesAfterWorkers) else {
      return nil
    }
    landFinished(.done, on: key, isSeen: isSeen)
    update(key) { $0.programFinishShown = .done }
    let note = SessionNote(state: .done, message: entry.programRecords.finishMessage)
    noteIfStanding(note, on: key)
    return note
  }
}
