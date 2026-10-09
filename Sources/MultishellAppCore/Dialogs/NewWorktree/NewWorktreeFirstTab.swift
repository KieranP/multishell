/// What the New Worktree sheet asks the created worktree's first tab to run.
public enum NewWorktreeFirstTab: Equatable, Sendable {
  /// An empty task starts the agent with nothing to do.
  case agent(String, task: String)
  case shell

  var startsAgent: Bool {
    if case .agent = self { true } else { false }
  }
}
