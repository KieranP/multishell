import Foundation
import MultishellCore

extension AppModel {
  /// What the reconciler opens for a session: its shell, or the agent's command
  /// line. A restored tab resumes where it can, four not starting four agents.
  func preparedForLaunch(_ session: TerminalSession) -> TerminalSession {
    var prepared = session
    prepared.shellOverride = shellPath(forWorktree: session.worktreeID)
    guard let agentID = session.agentID else { return prepared }
    prepared.command = agentCommand(
      agentID, resume: restoredSessionIDs.contains(session.id), shell: prepared.shellPath,
      in: session.worktreeID)
    return prepared
  }

  /// `shell` takes over when the agent quits; the agent runs through the
  /// login shell. The worktree resolves the flag line's placeholders.
  private func agentCommand(
    _ id: String, resume: Bool, shell tabShell: String, in worktreeID: Worktree.ID
  ) -> [String]? {
    let (shell, handOver) = TabCommand.loginShell(handingOverTo: tabShell)
    let values = placeholderValues(in: worktreeID)
    if id == AgentCatalogue.customID {
      return TabCommand.running(
        customLine: AgentCatalogue.customCommandLine(workspace.customAgentCommand, values: values),
        shell: shell, handOver: handOver)
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
    return TabCommand.running(arguments + flags, shell: shell, handOver: handOver)
  }

  /// The flag line in force for a worktree's project, or none where the
  /// worktree's project has gone.
  private func agentFlags(_ id: String, in worktreeID: Worktree.ID) -> String {
    guard let worktree = workspace.worktree(worktreeID), let project = resolvedProject(of: worktree)
    else { return "" }
    return workspace.agentFlags(for: project, agent: id)
  }

  /// What `{{branch}}` and the rest stand for here. Empty where the worktree
  /// has gone, leaving each placeholder as typed.
  private func placeholderValues(in worktreeID: Worktree.ID) -> [AgentPlaceholder: String] {
    guard let worktree = workspace.worktree(worktreeID), let project = resolvedProject(of: worktree)
    else { return [:] }
    return AgentPlaceholder.values(
      project: project, worktree: worktree, worktreeName: workspace.displayName(of: worktree))
  }

  /// Once per agent per run, like an unreachable project: every relaunch of
  /// a saved tab would otherwise raise it again.
  private func reportMissingAgentOnce(_ id: String, name: String) {
    guard reportedMissingAgents.insert(id).inserted else { return }
    presentedError = .agentNotInstalled(name)
  }
}
