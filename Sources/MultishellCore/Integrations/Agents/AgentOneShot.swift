/// How an agent answers one prompt and exits, no tool of its own able to
/// touch the worktree. Auto Rename's run; see Docs/design/agents.md.
public struct AgentOneShot: Hashable, Sendable {
  /// The subcommand, the print mode and the tools taken away, in that order.
  private let leadingArguments: [String]
  private let promptArgument: AgentTaskArgument
  private let modelFlag = AgentOption(name: "--model")
  /// `nil` for an agent with no effort flag, which runs at its own default.
  private let effortFlag: AgentOption?
  /// Laid over the login shell's, for what an agent takes no flag for.
  public let environment: [String: String]
  /// What Rename model offers; Docs/design/agents.md says why they are a list.
  public let models: [AgentModel]

  public var takesEffort: Bool { effortFlag != nil }

  init(
    leadingArguments: [String],
    promptArgument: AgentTaskArgument,
    models: [AgentModel],
    effortFlag: AgentOption? = nil,
    environment: [String: String] = [:],
  ) {
    self.leadingArguments = leadingArguments
    self.promptArgument = promptArgument
    self.effortFlag = effortFlag
    self.environment = environment
    self.models = models
  }

  /// Those of `id`, else what every listed model takes, as the default model
  /// or an id the catalogue dropped runs as whichever the user's config names.
  public func efforts(forModel id: String?) -> [String] {
    if let listed = models.first(where: { $0.id == id }) { return listed.efforts }
    guard let first = models.first else { return [] }
    return first.efforts.filter { effort in models.allSatisfy { $0.efforts.contains(effort) } }
  }

  public func offers(model id: String) -> Bool {
    models.contains { $0.id == id }
  }

  /// What every setter and the run check an effort by, so none reaches a CLI
  /// that its model does not take.
  public func offers(effort: String, withModel model: String?) -> Bool {
    efforts(forModel: model).contains(effort)
  }

  /// Run directly, not through a shell, so the prompt keeps its line breaks.
  public func arguments(prompt: String, model: String?, effort: String?) -> [String] {
    var arguments = leadingArguments
    if let model { arguments += modelFlag.arguments(model) }
    if let effortFlag, let effort { arguments += effortFlag.arguments(effort) }
    return arguments + promptArgument.arguments(forPrompt: prompt)
  }
}
