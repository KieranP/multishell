/// A project's override where it has one, else the global. These read
/// `project.settings`, so the project must be the one `AppModel.effectiveProject(_:)` made.
extension Workspace {
  /// The editor Open in Editor uses, or `nil` for none.
  public var effectiveEditorID: String? {
    EditorCatalogue.effectiveID(preferredEditorID)
  }

  /// The All Projects switches that start the agent as a project follows them: off
  /// with no global agent, as their switches are then greyed and cannot be turned off.
  public var autoStartsAgentGlobally: Bool { autoStartsAgent && hasGlobalAgent }

  public var autoStartsAgentOnCreateGlobally: Bool { autoStartsAgentOnCreate && hasGlobalAgent }

  public var sendsConflictsToPreferredAgentGlobally: Bool {
    sendsConflictsToPreferredAgent && hasGlobalAgent
  }

  /// Whether All Projects names an agent; a blank or None does not.
  public var hasGlobalAgent: Bool {
    AgentCatalogue.effectiveID(global: preferredAgentID, override: nil) != nil
  }

  public func effectiveWorktreeSettings(for project: Project) -> WorktreeSettings {
    project.settings.effectiveWorktreeSettings(defaults: worktreeDefaults)
  }

  /// The agent New Agent Tab starts in this project, or `nil` for none.
  public func effectiveAgentID(for project: Project) -> String? {
    AgentCatalogue.effectiveID(
      global: preferredAgentID,
      override: project.settings.preferredAgentID,
    )
  }

  /// The project's flags where they override and `id` is its agent, else the
  /// global line for `id`. Blank is the override to none; see settings.md.
  public func effectiveAgentFlags(for project: Project, agent id: String) -> String {
    let override = effectiveAgentID(for: project) == id ? project.settings.agentFlags : nil
    return override ?? agentFlags[id] ?? ""
  }

  /// The global flag line of the agent this project runs, which its own
  /// override may have chosen: what a flags override falls back to.
  public func globalAgentFlags(for project: Project) -> String {
    effectiveAgentID(for: project).map { agentFlags[$0] ?? "" } ?? ""
  }

  /// Whether a new tab in this project starts its agent: the project's say
  /// when it has one, else the global, and only when an agent is in force.
  public func autoStartsAgent(for project: Project) -> Bool {
    (project.settings.autoStartsAgent ?? autoStartsAgentGlobally)
      && effectiveAgentID(for: project) != nil
  }

  /// The same for the tab a worktree created here opens.
  public func autoStartsAgentOnCreate(for project: Project) -> Bool {
    (project.settings.autoStartsAgentOnCreate ?? autoStartsAgentOnCreateGlobally)
      && effectiveAgentID(for: project) != nil
  }

  /// Whether a merge or rebase here that stops on conflicts opens the agent on
  /// them unasked: the project's say, else the global, and only with an agent in force.
  public func sendsConflictsToPreferredAgent(for project: Project) -> Bool {
    (project.settings.sendsConflictsToPreferredAgent ?? sendsConflictsToPreferredAgentGlobally)
      && effectiveAgentID(for: project) != nil
  }

  /// Whether a worktree in this project opens a terminal when it is turned
  /// to: the project's say when it has one, else the global.
  public func opensTerminalOnSelect(for project: Project) -> Bool {
    project.settings.opensTerminalOnSelect ?? opensTerminalOnSelect
  }

  /// The same for a worktree just created here.
  public func opensTerminalOnCreate(for project: Project) -> Bool {
    project.settings.opensTerminalOnCreate ?? opensTerminalOnCreate
  }

  /// The order this project's worktree rows are listed in: the project's
  /// say when it has one, else the global.
  public func effectiveWorktreeSortOrder(for project: Project) -> WorktreeSortOrder {
    project.settings.worktreeSortOrder ?? worktreeSortOrder
  }

  /// Whether this project lifts its active worktrees to the top of its block.
  public func showsActiveWorktreesFirst(for project: Project) -> Bool {
    project.settings.showsActiveWorktreesFirst ?? showsActiveWorktreesFirst
  }

  /// The shell a new tab in this project runs, or `nil` for `$SHELL`.
  public func effectiveShellPath(for project: Project) -> String? {
    ShellChoice.effectivePath(
      global: preferredShellID,
      override: project.settings.preferredShellID,
      customPath: customShellPath,
    )
  }
}
