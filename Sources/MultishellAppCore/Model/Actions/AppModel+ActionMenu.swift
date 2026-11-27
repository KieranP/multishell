import MultishellCore

extension AppModel {
  /// The Terminal menu's Actions submenu: the selected worktree's actions in
  /// force, grouped as the play menu's are.
  public var actionMenuBarGroups: [[ActionMenuBarItem]] {
    guard let worktree = workspace.selectedWorktree,
      let project = workspace.project(worktree.projectID)
    else { return [] }
    let shortcuts = project.settings.actionShortcuts
    return actionGroupsInForce(for: worktree, of: project).map { group in
      group.map { ActionMenuBarItem(name: $0.name, keys: shortcuts.keys(for: $0.name)) }
    }
  }

  /// The user's own in force, then the file's; an empty group left out.
  private func actionGroupsInForce(
    for worktree: Worktree,
    of project: Project,
  ) -> [[ProjectAction]] {
    let own = ownActionNamesStandingIn(in: project)
    let actions = actionsInForce(for: worktree)
    let groups = [
      actions.filter { own.contains($0.name) }, actions.filter { !own.contains($0.name) },
    ]
    return groups.filter { !$0.isEmpty }
  }

  /// The names of a `.multishell.json`'s actions waiting on a yes, an own
  /// action of the same name standing in for one.
  private func actionsAwaitingTrust(in project: Project) -> [String] {
    guard !trustsSharedSettings(of: project),
      let shared = project.sharedSettingsSnapshot.confined?.actions
    else { return [] }
    let own = ownActionNamesStandingIn(in: project)
    return shared.map(\.name).filter { !own.contains($0) }
  }

  /// What the play button offers in this worktree, empty but for Edit
  /// Actions… where its project has none.
  public func actionMenu(for worktree: Worktree) -> ActionMenu? {
    guard let project = workspace.project(worktree.projectID) else { return nil }
    let shortcuts = project.settings.actionShortcuts
    let groups = actionGroupsInForce(for: worktree, of: project).map { group in
      group.map { action in
        ActionMenuItem(
          name: action.name,
          state: actionRunState(of: action.name, in: worktree.id),
          keys: shortcuts.keys(for: action.name),
        )
      }
    }
    return ActionMenu(groups: groups, awaitingTrust: actionsAwaitingTrust(in: project))
  }

  /// The play menu's Edit Actions… and Review and Trust…: its project's
  /// Actions page, in the Settings window brought up.
  public func editActions(of worktree: Worktree) {
    showSettingsUnfiltered(.actions, in: .project(worktree.projectID))
    platform.show(.settings)
  }
}
