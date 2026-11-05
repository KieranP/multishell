import Foundation
import MultishellCore

extension AppModel {
  /// Whether the agent picker is on the custom command, whose field shows.
  public var usesCustomAgent: Bool {
    workspace.preferredAgentID == AgentCatalogue.customID
  }

  /// Whether any agent is chosen, without which neither auto-start has
  /// anything to start.
  public var hasPreferredAgent: Bool {
    globalAgentID != AgentCatalogue.noneID
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

  public func effectiveAgentID(for worktree: Worktree) -> String? {
    effectiveProject(of: worktree).flatMap(workspace.effectiveAgentID)
  }

  public func agentDisplayName(_ id: String) -> String {
    AgentCatalogue.displayName(id)
  }
}
