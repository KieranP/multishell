import MultishellProcess

/// The agent that last reported in a session and the process it named: what
/// is at a prompt is not what the tab was opened as.
struct ReportedAgent: Hashable, Sendable {
  let agentID: String
  /// The reporting program, when the report named one. A report without a
  /// pid is trusted for as long as the session lives.
  let pid: Int32?

  /// Whether the agent is still the one at the prompt. A cheap signal
  /// check, not a wait: nothing here blocks.
  var isAtThePrompt: Bool {
    guard let pid else { return true }
    return !KernelProcessTable.isGone(pid)
  }
}
