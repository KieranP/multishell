import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// Whose hooks and whether the command-line tool are installed. Six files,
  /// read here on the main actor: the settings rows ask after writing one.
  public func refreshAgentStatus() {
    note(Self.agentStatus())
  }

  nonisolated static func agentStatus() -> AgentStatus {
    let installations = AgentHooks.integrations.map { ($0.id, $0.installation()) }
    return AgentStatus(
      hooks: Set(installations.filter { $0.1 != .absent }.map(\.0)),
      staleHooks: Set(installations.filter { $0.1 == .stale }.map(\.0)),
      tool: HelperLink.isCommandLineToolInstalled)
  }

  struct AgentStatus: Sendable {
    let hooks: Set<String>
    let staleHooks: Set<String>
    let tool: Bool
  }

  func note(_ status: AgentStatus) {
    setIfChanged(\.installedAgentHooks, status.hooks)
    setIfChanged(\.staleAgentHooks, status.staleHooks)
    setIfChanged(\.commandLineToolInstalled, status.tool)
  }
}

extension AppModel {
  public func setPreferredAgent(_ id: String?) {
    store.setPreferredAgent(id == AgentCatalogue.noneID ? nil : id)
  }

  public func setCustomAgentCommand(_ command: String) {
    store.setCustomAgentCommand(command)
    refreshInstalledAgents()
  }

  public func setAgentFlags(_ flags: String, for id: String) {
    store.setAgentFlags(flags, for: id)
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
    return workspace.preferredAgentID(for: project)
  }

  public func agentDisplayName(_ id: String) -> String {
    AgentCatalogue.displayName(id)
  }

  /// Which agent a tab draws the mark of, `nil` for a shell. The last step
  /// is a scan of every session, so a strip asks this once per tab.
  public func agentID(of tab: TerminalTab) -> String? {
    if let reported = reportedAgents[tab.focusedSessionID], reported.isAtThePrompt {
      return reported.agentID
    }
    if let running = commandAgents[tab.focusedSessionID] { return running }
    return workspace.session(tab.focusedSessionID)?.agentID
  }

  /// One pane's own, for its sidebar row and its card.
  public func agentID(ofPane session: TerminalSession) -> String? {
    agentAtThePrompt(of: session)
  }

  /// Cmd+Option+T: a tab running the preferred agent. The store records the
  /// agent id; the command line is built when the shell starts.
  public func newAgentTab() {
    guard let worktree = worktreeReadyForShell() else { return }
    guard let agentID = preferredAgentID(for: worktree) else {
      presentedError = .noAgentChosen
      return
    }
    openAgentTab(agentID, in: worktree, group: nil)
  }

  /// A strip's New Tab menu, which names the agent, so what the project
  /// prefers does not come into it.
  public func newAgentTab(_ agentID: String, in group: TabGroup.ID? = nil) {
    guard let worktree = worktreeReadyForShell() else { return }
    openAgentTab(agentID, in: worktree, group: group)
  }

  private func openAgentTab(_ agentID: String, in worktree: Worktree, group: TabGroup.ID?) {
    store.openTab(
      in: worktree.id, group: group, title: agentDisplayName(agentID), agentID: agentID)
    reconcileSessions(takingFocus: true)
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

  /// What the registry opens for a session: its shell, or the agent's command
  /// line. A restored tab resumes where it can, four not starting four agents.
  public func prepared(_ session: TerminalSession) -> TerminalSession {
    var prepared = session
    prepared.shell = shellPath(forWorktree: session.worktreeID)
    guard let agentID = session.agentID else { return prepared }
    prepared.command = agentCommand(
      agentID, resume: restoredSessionIDs.contains(session.id), shell: prepared.shellPath,
      in: session.worktreeID)
    return prepared
  }

  /// `shell` takes over when the agent quits; the agent runs through the
  /// login shell. The worktree resolves the flag line's placeholders.
  func agentCommand(
    _ id: String, resume: Bool, shell tabShell: String, in worktreeID: Worktree.ID
  ) -> [String]? {
    guard let shell = ShellCommand.shell else { return nil }
    let exec = ShellLaunch.execCommandLine(forShell: tabShell)
    let values = placeholderValues(in: worktreeID)
    if id == AgentCatalogue.customID {
      return TabCommand.running(
        customLine: AgentFlags.customLine(workspace.customAgentCommand, values: values),
        shell: shell, exec: exec)
    }
    guard let agent = AgentCatalogue.agent(id) else {
      reportMissingAgentOnce(id, name: id)
      return nil
    }
    // Until the login shell has answered, detection knows nothing; let the
    // shell say "command not found" in the tab rather than refuse here.
    if loginEnvironment != nil, !agentDetection.isInstalled(id) {
      reportMissingAgentOnce(id, name: agent.name)
      return nil
    }
    guard let arguments = AgentLaunch.arguments(for: agent, resume: resume) else { return nil }
    let flags = AgentFlags.arguments(agentFlags(id, in: worktreeID), values: values)
    return TabCommand.running(arguments + flags, shell: shell, exec: exec)
  }

  /// The flag line in force for a worktree's project, or none where the
  /// worktree's project has gone.
  private func agentFlags(_ id: String, in worktreeID: Worktree.ID) -> String {
    guard let project = project(owning: worktreeID) else { return "" }
    return workspace.agentFlags(for: project, agent: id)
  }

  /// What `{{branch}}` and the rest stand for here. Empty where the worktree
  /// has gone, leaving each placeholder as typed.
  private func placeholderValues(in worktreeID: Worktree.ID) -> [AgentPlaceholder: String] {
    guard let worktree = workspace.worktree(worktreeID),
      let project = project(owning: worktreeID)
    else { return [:] }
    return AgentPlaceholder.values(
      project: project, worktree: worktree, name: workspace.displayName(of: worktree))
  }

  /// The project with its repository's `.multishell.json` layered in, since
  /// every settings resolution has to be asked of the model.
  private func project(owning worktreeID: Worktree.ID) -> Project? {
    guard let worktree = workspace.worktree(worktreeID),
      let project = workspace.project(worktree.projectID)
    else { return nil }
    return resolved(project)
  }

  /// Once per agent per run, like an unreachable project: every relaunch of
  /// a saved tab would otherwise raise it again.
  private func reportMissingAgentOnce(_ id: String, name: String) {
    guard reportedMissingAgents.insert(id).inserted else { return }
    presentedError = .agentNotInstalled(name)
  }
}

extension AppModel {
  /// The agents Settings > Agents offers hooks for: the ones this machine
  /// has, and any whose hooks are still installed.
  public var agentHooksRows: [AgentHooksRow] {
    AgentHooksRow.rows(
      detection: agentDetection, installed: installedAgentHooks, stale: staleAgentHooks)
  }

  /// The file as it would be written, for the row that shows it.
  public func agentHooksSnippet(_ id: String) -> String {
    AgentHooks.integration(for: id)?.snippet() ?? ""
  }

  public func installAgentHooks(_ id: String) {
    guard let integration = AgentHooks.integration(for: id) else { return }
    do {
      try integration.install()
    } catch {
      report(error)
    }
    refreshAgentStatus()
  }

  public func removeAgentHooks(_ id: String) {
    guard let integration = AgentHooks.integration(for: id) else { return }
    do {
      try integration.remove()
    } catch {
      report(error)
    }
    refreshAgentStatus()
  }

  public func installCommandLineTool() {
    do {
      try platform.installCommandLineTool()
    } catch {
      report(error)
    }
    refreshAgentStatus()
  }
}
