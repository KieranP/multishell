import Foundation
import MultishellCore

extension AppModel {
  /// What the reconciler opens for a session: its shell, or the agent's command
  /// line. A restored tab resumes where it can, four not starting four agents.
  /// A task is the first launch's alone.
  func preparedForLaunch(_ session: TerminalSession) -> TerminalSession {
    var prepared = session
    prepared.shellOverride = shellPath(forWorktree: session.worktreeID)
    guard let agentID = session.agentID else { return prepared }
    prepared.command = agentCommand(
      agentID, resume: restoredSessionIDs.contains(session.id), shell: prepared.shellPath,
      in: session.worktreeID, task: pendingAgentTasks.removeValue(forKey: session.id))
    return prepared
  }

  /// `shell` takes over when the agent quits; the agent runs through the
  /// login shell. The worktree resolves the flag line's placeholders.
  private func agentCommand(
    _ id: String, resume: Bool, shell tabShell: String, in worktreeID: Worktree.ID,
    task: String?
  ) -> [String]? {
    let (shell, handOver) = TabCommand.loginShell(handingOverTo: tabShell)
    let place = worktreeAndProject(worktreeID)
    let values = place.map(placeholderValues) ?? [:]
    if id == AgentCatalogue.customID {
      return TabCommand.running(
        customLine: AgentCatalogue.customCommandLine(
          workspace.customAgentCommand, values: values, task: task ?? ""),
        shell: shell, handOver: handOver)
    }
    guard let agent = AgentCatalogue.agent(id) else {
      alertMissingAgentOnce(id, name: id)
      return nil
    }
    // Until the login shell has answered, detection knows nothing; let the
    // shell say "command not found" in the tab rather than refuse here.
    if loginEnvironment != nil, !agentDetection.isInstalled(id) {
      alertMissingAgentOnce(id, name: agent.name)
      return nil
    }
    guard let arguments = AgentLaunch.arguments(for: agent, resume: resume) else { return nil }
    // No flag line and each placeholder left as typed where the project has gone.
    let flagLine = place.map { workspace.effectiveAgentFlags(for: $0.project, agent: id) } ?? ""
    let flags = AgentFlags.arguments(flagLine, values: values)
    let taskArguments = task.map(agent.taskArgument.arguments(for:)) ?? []
    return TabCommand.running(arguments + flags + taskArguments, shell: shell, handOver: handOver)
  }

  private func worktreeAndProject(
    _ worktreeID: Worktree.ID
  ) -> (worktree: Worktree, project: Project)? {
    guard let worktree = workspace.worktree(worktreeID),
      let project = effectiveProject(of: worktree)
    else { return nil }
    return (worktree, project)
  }

  /// What `{{branch}}` and the rest stand for here.
  private func placeholderValues(
    _ place: (worktree: Worktree, project: Project)
  ) -> [WorktreePlaceholder: String] {
    WorktreePlaceholder.values(
      project: place.project, worktree: place.worktree,
      worktreeName: workspace.displayName(of: place.worktree))
  }

  /// Once per agent per run, like an unreachable project: every relaunch of
  /// a saved tab would otherwise raise it again.
  private func alertMissingAgentOnce(_ id: String, name: String) {
    guard alertedMissingAgentIDs.insert(id).inserted else { return }
    presentedError = .agentNotInstalled(name)
  }
}
