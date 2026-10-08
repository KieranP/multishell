import Foundation
import MultishellCore

extension AppModel {
  public func setPreferredAgent(_ id: String?) {
    store.setPreferredAgent(id == AgentCatalogue.noneID ? nil : id)
  }

  public func setCustomAgentCommand(_ command: String) {
    store.setCustomAgentCommand(command)
    refreshNewTabAgents()
  }

  /// Whether the agent picker is on the custom command, whose field shows.
  public var usesCustomAgent: Bool {
    workspace.preferredAgentID == AgentCatalogue.customID
  }

  /// Whether any agent is chosen, without which neither auto-start has
  /// anything to start.
  public var hasPreferredAgent: Bool {
    globalAgentID != AgentCatalogue.noneID
  }

  public func setAgentFlags(_ flags: String, for id: String) {
    store.setAgentFlags(flags, for: id)
  }

  /// The agent-flags override's footer while it is off: the global line in
  /// force for this project, or that there is none.
  public func globalAgentFlagsCaption(for project: Project) -> String {
    let flags = workspace.globalAgentFlags(for: project)
    return flags.isEmpty
      ? t("project.using-global-flags-none") : t("project.using-global-flags", flags)
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

  /// The agent picker's row for the global choice, None where nothing is
  /// stored. What a project inherits and shows while not overriding it.
  public var globalAgentID: String {
    workspace.preferredAgentID ?? AgentCatalogue.noneID
  }
}
