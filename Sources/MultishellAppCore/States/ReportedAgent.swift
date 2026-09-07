import Foundation
import MultishellProcess

/// The agent that last reported in a session, and the process it named.
///
/// What is at a pane's prompt is not what its tab was opened as: an agent
/// is usually started by hand in a plain shell tab, and a tab opened for
/// one keeps its `agentID` long after the agent has quit. Claude Code's
/// hooks report their own process, so the pid is what tells those apart —
/// once it has left the table the prompt belongs to the shell again.
public struct ReportedAgent: Hashable, Sendable {
  public let agentID: String
  /// The reporting program, when the report named one. A report without a
  /// pid is trusted for as long as the session lives.
  public let pid: Int32?

  public init(agentID: String, pid: Int32?) {
    self.agentID = agentID
    self.pid = pid
  }

  /// Whether the agent is still the one at the prompt. A cheap signal
  /// check, not a wait: nothing here blocks.
  public var isAtThePrompt: Bool {
    guard let pid else { return true }
    return !ProcessAncestry.isGone(pid)
  }
}
