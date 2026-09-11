import Foundation
import MultishellProcess

/// The agent that last reported in a session and the process it named: what
/// is at a prompt is not what the tab was opened as.
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
