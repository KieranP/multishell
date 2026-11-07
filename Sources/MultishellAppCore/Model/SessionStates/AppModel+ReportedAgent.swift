import Foundation
import MultishellCore

extension AppModel {
  /// The agent a hook names at the prompt. A report naming no directory keeps
  /// the one an earlier report gave the same agent.
  func noteReportedAgent(
    _ agentID: String,
    pid: Int32?,
    directory: URL?,
    in id: TerminalSession.ID,
  ) {
    let known = reportedAgents[id]
    if let directory {
      reportedAgentDirectories[id] = directory
    } else if known?.agentID != agentID {
      reportedAgentDirectories[id] = nil
    }
    setIfChanged(\.reportedAgents[id], ReportedAgent.reported(agentID, pid: pid, after: known))
  }

  /// The agent leaves the prompt with the directory it gave, or the next agent
  /// would write its mentions from there.
  func forgetReportedAgent(in id: TerminalSession.ID) {
    reportedAgentDirectories[id] = nil
    setIfChanged(\.reportedAgents[id], nil)
  }

  /// A hold's agent leaving takes the agent its hooks named with it, where they
  /// named that one. `true` where one went, for the caller's one badge update.
  func forgetReportedAgent(in id: TerminalSession.ID, ifItIs agentID: String) -> Bool {
    guard reportedAgents[id]?.agentID == agentID else { return false }
    forgetReportedAgent(in: id)
    return true
  }
}
