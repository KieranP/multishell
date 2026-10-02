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

  /// The agent id in force for a worktree's project, or `nil` for none.
  public func effectiveAgentID(for worktree: Worktree) -> String? {
    guard let project = workspace.project(worktree.projectID) else { return nil }
    return workspace.effectiveAgentID(for: project)
  }

  public func agentDisplayName(_ id: String) -> String {
    AgentCatalogue.displayName(id)
  }

  /// "New Claude Code Tab", and the typed command by its own name rather
  /// than as "New Custom command Tab".
  public func newAgentTabTitle(_ id: String) -> String {
    id == AgentCatalogue.customID
      ? t("tab.new-custom-agent") : t("tab.new-named-agent", agentDisplayName(id))
  }

  /// What a New Tab menu offers: the PATH scan's finds in catalogue order,
  /// then the custom command once typed. Run on either changing, never from a view.
  func refreshNewTabAgents() {
    var ids = AgentCatalogue.agents.map(\.id).filter(agentDetection.isInstalled)
    if !workspace.customAgentCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      ids.append(AgentCatalogue.customID)
    }
    setIfChanged(\.newTabAgentIDs, ids)
  }

  /// The agent picker's row for the global choice, None where nothing is
  /// stored. What a project inherits and shows while not overriding it.
  public var globalAgentID: String {
    workspace.preferredAgentID ?? AgentCatalogue.noneID
  }
}
