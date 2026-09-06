import AppKit
import MultishellCore
import MultishellProcess
import os

// MARK: - Login shell environment

extension AppModel {
  private static let logger = Logger(subsystem: "io.multishell.app", category: "environment")

  /// Asks the user's login shell for its environment once, off the main
  /// thread, and re-runs detection against its PATH. The Refresh in the
  /// agent dropdown calls it again.
  func refreshLoginEnvironment() async {
    let environment = await LoginShellEnvironment.capture()
    if case .processFallback(let reason) = environment.source {
      Self.logger.notice(
        "login shell environment unavailable, using the process's own: \(reason, privacy: .public)"
      )
    }
    loginEnvironment = environment
    agentDetection = AgentDetection(path: environment.path)
    shellDetection = ShellDetection(path: environment.path)
    editorDetection = EditorDetection(path: environment.path) {
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
    }
    refreshAgentStatus()
  }

  /// What the Agent settings show: whether the hooks and the command-line
  /// tool are installed. Read from disk on demand, not observed.
  func refreshAgentStatus() {
    let hooks = ClaudeCodeHooks.isInstalled()
    if hooks != claudeHooksInstalled { claudeHooksInstalled = hooks }
    let tool = HelperInstaller.isCommandLineToolInstalled
    if tool != commandLineToolInstalled { commandLineToolInstalled = tool }
  }
}

// MARK: - Preferred agent

extension AppModel {
  func setPreferredAgent(_ id: String?) {
    store.setPreferredAgent(id == AgentCatalogue.noneID ? nil : id)
  }

  func setCustomAgentCommand(_ command: String) {
    store.setCustomAgentCommand(command)
  }

  func setAutoStartAgent(_ enabled: Bool) {
    store.setAutoStartAgent(enabled)
  }

  /// The agent id in force for a worktree's project, or `nil` for none.
  func preferredAgentID(for worktree: Worktree) -> String? {
    guard let project = workspace.project(worktree.projectID) else { return nil }
    return workspace.preferredAgentID(for: project)
  }

  func agentDisplayName(_ id: String) -> String {
    if id == AgentCatalogue.customID { return "Custom command" }
    return AgentCatalogue.agent(id)?.name ?? id
  }

  /// Cmd+Shift+T: a tab running the preferred agent. The store records the
  /// agent id; the command line is built when the shell starts.
  func newAgentTab() {
    guard let worktree = workspace.selectedWorktree, !isBusy(worktree.id),
      directoryExists(of: worktree)
    else { return }
    guard let agentID = preferredAgentID(for: worktree) else {
      presentedError = PresentedError(
        title: "No agent chosen",
        message: "Pick a preferred agent in Settings > Agents, or in this project's settings.")
      return
    }
    store.openTab(in: worktree.id, title: agentDisplayName(agentID), agentID: agentID)
    sync()
  }

  /// What the registry opens for a session: the shell in force for its
  /// project, or the agent's command line with that shell taking over after
  /// it. A session that was saved by an earlier run resumes where the
  /// catalogue knows how, and is otherwise a plain shell with the agent's
  /// title; four saved agent tabs must not start four agents.
  func prepared(_ session: TerminalSession) -> TerminalSession {
    var prepared = session
    prepared.shell = shellPath(forWorktree: session.worktreeID)
    guard let agentID = session.agentID else { return prepared }
    prepared.command = agentCommand(
      agentID, resume: restoredSessionIDs.contains(session.id), shell: prepared.shellPath)
    return prepared
  }

  /// `shell` is the tab's shell, the one that takes over when the agent
  /// quits; the agent itself runs through the login shell for its PATH.
  func agentCommand(_ id: String, resume: Bool, shell tabShell: String) -> [String]? {
    guard let shell = ShellCommand.shell else { return nil }
    let exec = ShellLaunch.execCommandLine(forShell: tabShell)
    if id == AgentCatalogue.customID {
      return AgentLaunch.command(customLine: workspace.customAgentCommand, shell: shell, exec: exec)
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
    return AgentLaunch.command(agent: arguments, shell: shell, exec: exec)
  }

  /// Once per agent per run, like an unreachable project: every relaunch of
  /// a saved tab would otherwise raise it again.
  private func reportMissingAgentOnce(_ id: String, name: String) {
    guard reportedMissingAgents.insert(id).inserted else { return }
    presentedError = PresentedError(
      title: "\(name) is not installed",
      message:
        "The tab opened as a plain shell. Install \(name), or choose another agent in Settings > Agents, then use Refresh."
    )
  }
}

// MARK: - Claude Code hooks and the command-line tool

extension AppModel {
  var claudeHooksSnippet: String { ClaudeCodeHooks.snippet() }

  func installClaudeHooks() {
    do {
      try ClaudeCodeHooks.install()
    } catch {
      report(error)
    }
    refreshAgentStatus()
  }

  func removeClaudeHooks() {
    do {
      try ClaudeCodeHooks.remove()
    } catch {
      report(error)
    }
    refreshAgentStatus()
  }

  func installCommandLineTool() {
    do {
      try HelperInstaller.installCommandLineTool()
    } catch {
      report(error)
    }
    refreshAgentStatus()
  }

  static let claudeCodeSetupURL = URL(string: "https://code.claude.com/docs/en/setup")!
  static let claudeCodeInstallCommand = "curl -fsSL https://claude.ai/install.sh | bash"
}
