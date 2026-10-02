import MultishellCore

extension AppModel {
  /// Cmd+T: the preferred agent where auto-start is on, else a plain shell.
  /// A strip's button names its group; the keystroke names none.
  public func newTab(in group: TabGroup.ID? = nil) {
    guard let worktree = requireWorktreeForShell() else { return }
    addDefaultTab(in: worktree, for: .byUser, group: group)
    reconcileSessions(takingFocus: true)
  }

  /// Cmd+Shift+T: always a plain shell, so one stays reachable when every
  /// New Tab starts an agent. A strip's menu names its group.
  public func newShellTab(in group: TabGroup.ID? = nil) {
    guard let worktree = requireWorktreeForShell() else { return }
    store.openTab(in: worktree.id, group: group)
    reconcileSessions(takingFocus: true)
  }

  /// Cmd+Option+T: a tab running the preferred agent. The store records the
  /// agent id; the command line is built when the shell starts.
  public func newAgentTab() {
    guard let worktree = requireWorktreeForShell() else { return }
    guard let agentID = effectiveAgentID(for: worktree) else {
      presentedError = .noAgentChosen
      return
    }
    openAgentTab(agentID, in: worktree, group: nil)
  }

  /// A strip's New Tab menu, which names the agent, so what the project
  /// prefers does not come into it.
  public func newAgentTab(_ agentID: String, in group: TabGroup.ID? = nil) {
    guard let worktree = requireWorktreeForShell() else { return }
    openAgentTab(agentID, in: worktree, group: group)
  }

  private func openAgentTab(_ agentID: String, in worktree: Worktree, group: TabGroup.ID?) {
    addAgentTab(agentID, in: worktree, group: group)
    reconcileSessions(takingFocus: true)
  }

  /// The store's half alone, for a caller that reconciles later.
  private func addAgentTab(_ agentID: String, in worktree: Worktree, group: TabGroup.ID?) {
    store.openTab(
      in: worktree.id, group: group, title: agentDisplayName(agentID), agentID: agentID)
  }

  /// What a new tab is by default here, and the first tab a worktree gets
  /// when selected or created.
  func addDefaultTab(in worktree: Worktree, for reason: TabOpeningReason, group: TabGroup.ID? = nil)
  {
    if let project = effectiveProject(of: worktree),
      autoStartsAgent(in: project, for: reason),
      let agentID = workspace.effectiveAgentID(for: project)
    {
      addAgentTab(agentID, in: worktree, group: group)
    } else {
      store.openTab(in: worktree.id, group: group)
    }
  }

  /// Nothing running there, no tab yet, and the setting for this reason says
  /// open one.
  func wantsFirstTab(in worktree: Worktree, for reason: TabOpeningReason) -> Bool {
    !isBusy(worktree.id) && workspace.tabs(in: worktree.id).isEmpty
      && opensTab(in: worktree, for: reason)
  }

  /// Whether a worktree with no tabs gets one for this reason. A worktree
  /// whose project has gone follows the global.
  private func opensTab(in worktree: Worktree, for reason: TabOpeningReason) -> Bool {
    let project = effectiveProject(of: worktree)
    return switch reason {
    case .byUser: true
    case .onSelect:
      project.map(workspace.opensTerminalOnSelect(for:)) ?? workspace.opensTerminalOnSelect
    case .onCreate:
      project.map(workspace.opensTerminalOnCreate(for:)) ?? workspace.opensTerminalOnCreate
    case .never: false
    }
  }

  /// Whether that tab runs the agent. Only a create asks the create setting;
  /// everything else follows auto-start on tab open.
  private func autoStartsAgent(in project: Project, for reason: TabOpeningReason) -> Bool {
    switch reason {
    case .onCreate: workspace.autoStartsAgentOnCreate(for: project)
    case .byUser, .onSelect, .never: workspace.autoStartsAgent(for: project)
    }
  }

  public func setOpensTerminalOnSelect(_ enabled: Bool) {
    store.setOpensTerminalOnSelect(enabled)
  }

  public func setOpensTerminalOnCreate(_ enabled: Bool) {
    store.setOpensTerminalOnCreate(enabled)
  }

  /// A worktree menu's New Shell Tab: that worktree selected first, so the tab
  /// opens where it was asked for, and nothing opened where it cannot be.
  public func newShellTab(selecting worktree: Worktree) {
    guard select(worktree, openingFirstTab: .never) else { return }
    newShellTab()
  }

  /// The same for New Agent Tab, starting the agent the project prefers.
  public func newAgentTab(selecting worktree: Worktree) {
    guard select(worktree, openingFirstTab: .never) else { return }
    newAgentTab()
  }
}
