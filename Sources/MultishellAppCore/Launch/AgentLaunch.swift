import MultishellCore

/// The arguments an agent tab starts with; `TabCommand` puts them in a line.
enum AgentLaunch {
  /// A reported conversation resumes by id, as the latest's flag reopens another tab's;
  /// `nil` with nothing to resume, a plain shell keeping the title.
  static func arguments(
    for agent: AgentDescriptor,
    resume: Bool,
    conversation: String? = nil,
    besideAnotherTabOfItsAgent: Bool = false,
  ) -> [String]? {
    guard resume else { return [agent.executable] }
    if let conversation, let byID = agent.conversationResumeArguments {
      let placeholder = AgentDescriptor.conversationPlaceholder
      return [agent.executable] + byID.map { $0.replacing(placeholder, with: conversation) }
    }
    guard let latest = agent.resumeArguments else { return nil }
    return besideAnotherTabOfItsAgent ? [agent.executable] : [agent.executable] + latest
  }
}
