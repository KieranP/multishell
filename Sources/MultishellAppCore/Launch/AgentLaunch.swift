import MultishellCore

/// The arguments an agent tab starts with; `TabCommand` puts them in a line.
enum AgentLaunch {
  /// A reported conversation resumes by id, the latest's flag reopening another tab's.
  /// `nil` when there is nothing to resume with: a plain shell keeping the title.
  static func arguments(
    for agent: AgentDescriptor,
    resume: Bool,
    conversation: String? = nil,
  ) -> [String]? {
    guard resume else { return [agent.executable] }
    if let conversation, let byID = agent.conversationResumeArguments {
      let placeholder = AgentDescriptor.conversationPlaceholder
      return [agent.executable] + byID.map { $0.replacing(placeholder, with: conversation) }
    }
    return agent.resumeArguments.map { [agent.executable] + $0 }
  }
}
