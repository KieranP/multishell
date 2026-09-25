/// A project's override where it has one, else the global. These read
/// `project.settings`, so the project must be the one `AppModel.resolved` made.
extension Workspace {
  public func worktreeSettings(for project: Project) -> WorktreeSettings {
    project.settings.effectiveWorktreeSettings(defaults: worktreeDefaults)
  }

  /// The agent New Agent Tab starts in this project, or `nil` for none.
  public func effectiveAgentID(for project: Project) -> String? {
    AgentCatalogue.effectiveID(
      global: preferredAgentID, override: project.settings.preferredAgentID)
  }

  /// The project's flag line where it overrides, else the global one for
  /// that agent. Blank is the override to none; see settings.md.
  public func agentFlags(for project: Project, agent id: String) -> String {
    project.settings.agentFlags ?? agentFlags[id] ?? ""
  }

  /// The global flag line of the agent this project runs, which its own
  /// override may have chosen: what a flags override falls back to.
  public func globalAgentFlags(for project: Project) -> String {
    effectiveAgentID(for: project).map { agentFlags[$0] ?? "" } ?? ""
  }

  /// Whether a new tab in this project starts its agent: the project's say
  /// when it has one, else the global, and only when an agent is in force.
  public func autoStartsAgent(for project: Project) -> Bool {
    (project.settings.autoStartAgent ?? autoStartAgent) && effectiveAgentID(for: project) != nil
  }

  /// The same for the tab a worktree created here opens.
  public func autoStartsAgentOnCreate(for project: Project) -> Bool {
    (project.settings.autoStartAgentOnCreate ?? autoStartAgentOnCreate)
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
  public func worktreeSortOrder(for project: Project) -> WorktreeSortOrder {
    project.settings.worktreeSortOrder ?? worktreeSortOrder
  }

  /// Whether this project lifts its busy worktrees to the top of its block.
  public func showsActiveWorktreesFirst(for project: Project) -> Bool {
    project.settings.showsActiveWorktreesFirst ?? showsActiveWorktreesFirst
  }

  /// The shell a new tab in this project runs, or `nil` for `$SHELL`.
  public func effectiveShellPath(for project: Project) -> String? {
    ShellCatalogue.effectivePath(
      global: preferredShellID, override: project.settings.preferredShellID,
      customPath: customShellPath)
  }

  /// The editor Open in Editor uses, or `nil` for none.
  public var effectiveEditorID: String? {
    EditorCatalogue.effectiveID(preferredEditorID)
  }
}
