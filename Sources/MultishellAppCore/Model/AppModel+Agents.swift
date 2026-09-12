import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

// MARK: - Login shell environment

extension AppModel {
  /// Asks the login shell for its environment once, off the main thread, and
  /// re-runs detection against its PATH.
  public func refreshLoginEnvironment() async {
    let environment = await LoginShellEnvironment.capture()
    if case .processFallback(let reason) = environment.source {
      platform.log("login shell environment unavailable, using the process's own: \(reason)")
    }
    loginEnvironment = environment
    // The bundle lookups answer from LaunchServices' own database and need
    // the platform, so they stay; it is the PATH that has to be left.
    let applications = EditorCatalogue.editors.reduce(into: [String: URL]()) { found, editor in
      guard let id = editor.bundleIdentifier, let url = platform.applicationURL(forIdentifier: id)
      else { return }
      found[id] = url
    }
    // A stat per PATH directory per catalogue entry, and every one of them
    // blocks for the timeout on a mount that has gone; see architecture.md.
    let path = environment.path
    let detected = await Self.offMain {
      (
        agents: AgentDetection(path: path), shells: ShellDetection(path: path),
        editors: EditorDetection(path: path) { applications[$0] }
      )
    }
    agentDetection = detected.agents
    shellDetection = detected.shells
    editorDetection = detected.editors
    // git on the login shell's PATH like every other tool, which launch could
    // not reach. Finding it here takes back what launch reported.
    if worktrees == nil, let found = try? WorktreeCoordinator(path: environment.path) {
      worktrees = found
      if presentedError?.title == PresentedError(GitUnavailable()).title {
        presentedError = nil
      }
      // `start` refreshed before this ran and found no git, so every project
      // listed nothing; the sidebar stays empty until something asks again.
      await refreshAll()
    }
    refreshAgentStatus()
  }

  /// What the Agent settings show: whose hooks and whether the command-line
  /// tool are installed. Read from disk on demand, not observed.
  public func refreshAgentStatus() {
    let hooks = Set(AgentHooks.integrations.filter { $0.isInstalled() }.map(\.id))
    if hooks != installedAgentHooks { installedAgentHooks = hooks }
    let tool = HelperLink.isCommandLineToolInstalled
    if tool != commandLineToolInstalled { commandLineToolInstalled = tool }
  }
}

// MARK: - Preferred agent

extension AppModel {
  public func setPreferredAgent(_ id: String?) {
    store.setPreferredAgent(id == AgentCatalogue.noneID ? nil : id)
  }

  public func setCustomAgentCommand(_ command: String) {
    store.setCustomAgentCommand(command)
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

  /// Cmd+Option+T: a tab running the preferred agent. The store records the
  /// agent id; the command line is built when the shell starts.
  public func newAgentTab() {
    guard let worktree = worktreeReadyForShell() else { return }
    guard let agentID = preferredAgentID(for: worktree) else {
      presentedError = .noAgentChosen
      return
    }
    store.openTab(in: worktree.id, title: agentDisplayName(agentID), agentID: agentID)
    sync()
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
  public func agentCommand(
    _ id: String, resume: Bool, shell tabShell: String, in worktreeID: Worktree.ID
  ) -> [String]? {
    guard let shell = ShellCommand.shell else { return nil }
    let exec = ShellLaunch.execCommandLine(forShell: tabShell)
    let values = placeholderValues(in: worktreeID)
    if id == AgentCatalogue.customID {
      return AgentLaunch.command(
        customLine: AgentFlags.expand(workspace.customAgentCommand, values: values),
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
    return AgentLaunch.command(agent: arguments + flags, shell: shell, exec: exec)
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

// MARK: - Agent hooks and the command-line tool

extension AppModel {
  /// The agents Settings > Agents offers hooks for: the ones this machine
  /// has, and any whose hooks are still installed.
  public var agentHooksRows: [AgentHooksRow] {
    AgentHooksRow.rows(detection: agentDetection, installed: installedAgentHooks)
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
