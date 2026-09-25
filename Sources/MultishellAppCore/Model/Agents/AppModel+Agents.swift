import Foundation
import MultishellCore

extension AppModel {
  public func setPreferredAgent(_ id: String?) {
    store.setPreferredAgent(id == AgentCatalogue.noneID ? nil : id)
  }

  public func setCustomAgentCommand(_ command: String) {
    store.setCustomAgentCommand(command)
    refreshInstalledAgents()
  }

  /// Whether the agent picker is on the custom command, whose field shows.
  public var usesCustomAgent: Bool {
    workspace.preferredAgentID == AgentCatalogue.customID
  }

  /// Whether any agent is chosen, without which neither auto-start has
  /// anything to start.
  public var hasPreferredAgent: Bool {
    workspace.preferredAgentID != nil
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

  public func setAutoStartAgent(_ enabled: Bool) {
    store.setAutoStartAgent(enabled)
  }

  public func setAutoStartAgentOnCreate(_ enabled: Bool) {
    store.setAutoStartAgentOnCreate(enabled)
  }

  /// The agent id in force for a worktree's project, or `nil` for none.
  public func preferredAgentID(for worktree: Worktree) -> String? {
    guard let project = workspace.project(worktree.projectID) else { return nil }
    return workspace.effectiveAgentID(for: project)
  }

  public func agentDisplayName(_ id: String) -> String {
    AgentCatalogue.displayName(id)
  }

  /// Which agent a pane holds: the one that reported while its process is up,
  /// else the tab's own. Most panes get theirs typed at a shell prompt.
  public func agentAtThePrompt(of session: TerminalSession) -> String? {
    agentAtThePrompt(session.id, orOpenedAs: session.agentID)
  }

  /// Which agent a tab draws the mark of, `nil` for a shell. The last step
  /// is a scan of every session, so a strip asks this once per tab.
  public func agentAtThePrompt(of tab: TerminalTab) -> String? {
    agentAtThePrompt(
      tab.focusedSessionID, orOpenedAs: workspace.session(tab.focusedSessionID)?.agentID)
  }

  private func agentAtThePrompt(
    _ id: TerminalSession.ID, orOpenedAs openedAs: @autoclosure () -> String?
  ) -> String? {
    if let reported = reportedAgents[id], reported.isAtThePrompt { return reported.agentID }
    return commandAgentIDs[id] ?? openedAs()
  }

  /// Whether an agent is at this pane's prompt, the report winning over the
  /// tab's own id. Asked by the board and its counts alike.
  func isAgentPane(_ session: TerminalSession) -> Bool {
    agentAtThePrompt(of: session) != nil
  }

  /// What a New Tab menu offers: the PATH scan's finds in catalogue order,
  /// then the custom command once typed. Run on either changing, never from a view.
  func refreshInstalledAgents() {
    var ids = AgentCatalogue.agents.map(\.id).filter { agentDetection.found[$0] != nil }
    if !workspace.customAgentCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      ids.append(AgentCatalogue.customID)
    }
    setIfChanged(\.installedAgentIDs, ids)
  }
}
