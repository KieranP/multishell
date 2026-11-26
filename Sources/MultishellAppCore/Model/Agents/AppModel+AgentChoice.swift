import Foundation
import MultishellCore

extension AppModel {
  /// Whether the agent picker is on the custom command, whose field shows.
  public var usesCustomAgent: Bool {
    workspace.preferredAgentID == AgentCatalogue.customID
  }

  /// Whether any agent is chosen, without which neither auto-start has
  /// anything to start.
  public var hasPreferredAgent: Bool { workspace.hasGlobalAgent }

  /// Under a switch greyed for want of a preferred agent: where to pick one.
  public var preferredAgentNeededCaption: String? {
    hasPreferredAgent ? nil : t("settings.preferred-agent-needed")
  }

  /// The agent picker's row for the global choice, None where nothing is
  /// stored. What a project inherits and shows while not overriding it.
  public var globalAgentID: String {
    workspace.preferredAgentID ?? AgentCatalogue.noneID
  }

  public func setPreferredAgent(_ id: String?) {
    store.setPreferredAgent(id == AgentCatalogue.noneID ? nil : id)
  }

  public func setCustomAgentCommand(_ command: String) {
    store.setCustomAgentCommand(command)
    rebuildNewTabAgents()
  }

  public func setAgentFlags(_ flags: String, for id: String) {
    store.setAgentFlags(flags, for: id)
  }

  public func setAutoStartsAgent(_ enabled: Bool) {
    store.setAutoStartsAgent(enabled)
  }

  public func setAutoStartsAgentOnCreate(_ enabled: Bool) {
    store.setAutoStartsAgentOnCreate(enabled)
  }

  /// Whether the project runs an agent, its own or the global; a setting that
  /// starts one is greyed without.
  public func hasAgent(in project: Project) -> Bool {
    workspace.effectiveAgentID(for: effectiveProject(project)) != nil
  }

  /// Under a project's switch greyed while it has no agent: where to pick one.
  public func agentNeededCaption(in project: Project) -> String? {
    hasAgent(in: project) ? nil : t("settings.project-agent-needed")
  }

  public func effectiveAgentID(for worktree: Worktree) -> String? {
    effectiveProject(of: worktree).flatMap(workspace.effectiveAgentID)
  }

  public func agentDisplayName(_ id: String) -> String {
    AgentCatalogue.displayName(id)
  }
}
