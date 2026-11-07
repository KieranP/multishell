import Foundation
import MultishellCore

/// The OSC 7501 records a pane's program keeps about itself: its own and its
/// child records, such as background tasks. See Docs/design/agents/program-status.md.
struct ProgramStatusRecords: Equatable, Sendable {
  /// From the first report that kept a record until the program's own clear:
  /// a child's clear leaving nothing is not the program leaving.
  private(set) var isHolding = false
  /// States alone, so a program rewording its work changes nothing stored.
  private var ownState: ProgramStatus.State?
  /// The agent the hold is, decided once: a report naming no `app` mid-hold,
  /// or a hook of an agent the program ran, leaves it.
  private var agentID: String?
  /// The words of the program's own finish, for whichever report lands it.
  private(set) var finishMessage: String?
  /// Working and asking children only, the two that move the dot.
  private var childStates: [String: ProgramStatus.State] = [:]
  /// When the work the next finish ends began. Handed in.
  private var workStartedAt: Date?
  /// The program's process, kept past its Working so the poll can end a hold
  /// that rests on a finish or on idle.
  private(set) var pid: Int32?

  var agent: AgentDescriptor? {
    agentID.flatMap(AgentCatalogue.agent(_:))
  }

  /// What the dot shows. A child asking or working outranks the program's
  /// own finish, as a worker out holds a Stop's Done.
  var shownState: SessionState {
    if ownState == .blocked || childStates.values.contains(.blocked) { return .attention }
    if ownState == .working || childStates.values.contains(.working) { return .running }
    switch ownState {
    case .done: return .done
    case .failed: return .failed
    case .idle, .working, .blocked, .clear: return .idle

    // Known only by its children, it is at work for as long as it holds.
    case nil: return isHolding ? .running : .idle
    }
  }

  /// The words for the dot: a finish's are the program's own, whichever
  /// record let it land; otherwise only a report of the state shown speaks.
  func shownMessage(movedBy status: ProgramStatus, isAgent: Bool) -> String? {
    switch shownState {
    case .done, .failed: finishMessage
    case .attention: status.state == .blocked ? words(of: status, isAgent: isAgent) : nil
    case .running: status.state == .working ? status.message : nil
    case .idle: nil
    }
  }

  /// How long a finish took, from the start of the work it ends.
  func duration(endingAt now: Date) -> Double? {
    workStartedAt.map { now.timeIntervalSince($0) }
  }

  /// The agent a hook names for a hold whose program's `app` named none, and
  /// its process where the program's reports gave none.
  mutating func adoptAgent(_ agentID: String, pid: Int32?) {
    guard self.agentID == nil || self.agentID == agentID else { return }
    self.agentID = agentID
    if self.pid == nil { self.pid = pid }
  }

  /// The work began before the program first reported, as the shell's own
  /// report of the command said.
  mutating func backdateWork(to start: Date) {
    workStartedAt = start
  }

  /// A report replaces its record whole, and a child's clear takes the record
  /// and every one under it. The program's own clear ends the hold, its caller's.
  mutating func record(_ status: ProgramStatus, from pid: Int32?, at now: Date) {
    let before = shownState
    if let id = status.recordID {
      recordChild(status.state, id: id)
    } else {
      ownState = status.state
      if let named = status.app.flatMap(AgentCatalogue.agent(reportingStatusAs:)) {
        agentID = named.id
      }
      finishMessage = [.done, .failed].contains(status.state) ? status.message : nil
    }
    guard ownState != nil || !childStates.isEmpty || isHolding else { return }
    isHolding = true
    // The hold's own process: a later report can land while a child of it is
    // in front, whose exit is not the program's.
    if self.pid == nil { self.pid = pid }
    // Work starting, or a finish with no work before it, which took no time.
    let after = shownState
    if !before.isUnderway, after != before { workStartedAt = now }
  }

  private mutating func recordChild(_ state: ProgramStatus.State, id: String) {
    switch state {
    case .clear:
      childStates = childStates.filter { $0.key != id && !$0.key.hasPrefix(id + "/") }

    case .working, .blocked:
      guard childStates[id] != nil || childStates.count < SessionStateReport.rosterCapacity
      else { return }
      childStates[id] = state

    case .idle, .done, .failed:
      childStates[id] = nil
    }
  }

  /// A question the program left unworded is worded from the catalogue, as a
  /// hook's is, but only for an agent: a command asks in its own words.
  private func words(of status: ProgramStatus, isAgent: Bool) -> String? {
    guard status.message == nil, status.blockedReason == .question, isAgent else {
      return status.message
    }
    return NotificationPolicy.agentQuestion
  }
}
