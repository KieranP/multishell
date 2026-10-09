extension NewWorktreeDraft {
  /// The agent rows as a newly picked project has them: the switch where it
  /// auto-starts on creation, the picker on its agent. The task stays.
  public mutating func fitAgent(startsByDefault: Bool, preferred: String?, offered: [String]) {
    startsAgent = startsByDefault
    preferredAgentID = preferred
    agentID = ""
    offerAgents(offered)
  }

  /// The PATH scan can land after the sheet opens. A pick still offered
  /// stays; otherwise the project's agent, else the first offered.
  public mutating func offerAgents(_ offered: [String]) {
    offeredAgentIDs = offered
    guard !offered.contains(agentID) else { return }
    agentID = preferredAgentID.flatMap { offered.contains($0) ? $0 : nil } ?? offered.first ?? ""
  }

  public var offersAgents: Bool { !offeredAgentIDs.isEmpty }

  /// `nil` while nothing is offered, as before the PATH scan answers, so the
  /// create settings decide as they did without the sheet.
  public var firstTab: NewWorktreeFirstTab? {
    guard offersAgents else { return nil }
    guard startsAgent, offeredAgentIDs.contains(agentID) else { return .shell }
    return .agent(agentID, task: task.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}
