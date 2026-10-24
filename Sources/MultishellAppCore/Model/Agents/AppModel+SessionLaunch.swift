import Foundation
import MultishellCore
import MultishellProcess

extension AppModel {
  /// What the reconciler opens: the session's shell or agent line. A restored tab
  /// resumes where it can, four not starting four agents; a task rides the first launch.
  func preparedForLaunch(_ session: TerminalSession) -> TerminalSession {
    var prepared = session
    prepared.shellOverride = shellPath(forWorktree: session.worktreeID)
    prepared.port = workspace.port(of: session.worktreeID)
    guard let agentID = session.agentID else { return prepared }
    prepared.command = agentCommand(
      agentID,
      resume: restoredSessionIDs.contains(session.id),
      shell: prepared.shellPath,
      in: session.worktreeID,
      task: pendingAgentTasks.removeValue(forKey: session.id),
    )
    return prepared
  }

  /// `nil` for the custom agent. One not on PATH passes until the login shell
  /// has answered: detection knows nothing then, so the shell says it is missing.
  func agentStartProblem(_ id: String) -> AgentStartProblem? {
    guard id != AgentCatalogue.customID else { return nil }
    guard AgentCatalogue.agent(id) != nil else { return .notInCatalogue }
    guard loginEnvironment == nil || agentDetection.isInstalled(id) else { return .notInstalled }
    return nil
  }

  /// `shell` takes over when the agent quits; the agent runs through the
  /// login shell. The worktree resolves the flag line's placeholders.
  private func agentCommand(
    _ id: String,
    resume: Bool,
    shell tabShell: String,
    in worktreeID: Worktree.ID,
    task: String?,
  ) -> [String]? {
    let (shell, handOver) = TabCommand.loginShell(handingOverTo: tabShell)
    let place = worktreeAndProject(worktreeID)
    let values = place.map(placeholderValues) ?? [:]
    if id == AgentCatalogue.customID {
      return TabCommand.running(
        customLine: AgentCatalogue.customCommandLine(
          workspace.customAgentCommand,
          values: values,
          forShellNamed: shell.executable.lastPathComponent,
          task: task ?? "",
        ),
        shell: shell,
        handOver: handOver,
      )
    }
    guard let agent = AgentCatalogue.agent(id), agentStartProblem(id) == nil else {
      alertMissingAgentOnce(id, name: AgentCatalogue.agent(id)?.name ?? id)
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
      project: place.project,
      worktree: place.worktree,
      worktreeName: workspace.displayName(of: place.worktree),
      port: workspace.port(of: place.worktree.id),
    )
  }

  /// Once per agent per run, like an unreachable project: every relaunch of
  /// a saved tab would otherwise raise it again.
  private func alertMissingAgentOnce(_ id: String, name: String) {
    guard alertedMissingAgentIDs.insert(id).inserted else { return }
    presentedError = .agentNotInstalled(name)
  }
}
