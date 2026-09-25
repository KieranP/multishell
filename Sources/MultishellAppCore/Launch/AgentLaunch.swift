import MultishellCore

/// The arguments an agent tab starts with; `TabCommand` puts them in a line.
enum AgentLaunch {
  /// `nil` when a relaunch has nothing to resume with; the tab is then a
  /// plain shell that keeps the agent's title.
  static func arguments(for agent: AgentDescriptor, resume: Bool) -> [String]? {
    if resume {
      return agent.resumeArguments.map { [agent.executable] + $0 }
    }
    return [agent.executable] + agent.launchArguments
  }
}
