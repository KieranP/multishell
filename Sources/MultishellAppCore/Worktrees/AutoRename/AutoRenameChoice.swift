import MultishellCore

/// The agent, model and effort an Auto Rename runs, each checked against the
/// catalogue so nothing it does not list reaches a CLI.
struct AutoRenameChoice: Equatable {
  let agent: AgentDescriptor
  let model: String?
  let effort: String?

  /// No Rename agent means the project's agent at its own defaults; a custom
  /// command or no agent means nothing to run.
  static func resolve(
    renameAgentID: String?,
    model: String?,
    effort: String?,
    projectAgentID: String?,
  ) -> Self? {
    guard let renameAgentID else {
      return projectAgentID.flatMap { AgentCatalogue.agent($0) }.map { agent in
        Self(agent: agent, model: nil, effort: nil)
      }
    }
    guard let agent = AgentCatalogue.agent(renameAgentID) else { return nil }
    let oneShot = agent.oneShot
    let listedModel = model.flatMap { model in oneShot.offers(model: model) ? model : nil }
    let listedEffort = effort.flatMap { effort in
      oneShot.offers(effort: effort, withModel: listedModel) ? effort : nil
    }
    return Self(agent: agent, model: listedModel, effort: listedEffort)
  }
}
