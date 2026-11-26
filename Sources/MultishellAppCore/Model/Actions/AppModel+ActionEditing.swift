import MultishellCore

/// The Actions page's edits to the user's own actions.
extension AppModel {
  /// A blank row, named on the page; unnamed, it takes no keys or tabs.
  public func addAction(to project: Project) {
    var settings = ownSettings(of: project)
    settings.actions.append(ProjectAction(name: "", command: ""))
    setSettings(settings, for: project)
  }

  /// The name stored, trimmed; `nil` for a blank one or one another own action
  /// has. Keys and tabs move with it, bar a trusted file action's; see actions.md.
  @discardableResult
  public func setActionName(_ name: String, at index: Int, in project: Project) -> String? {
    var settings = ownSettings(of: project)
    guard settings.actions.indices.contains(index),
      let name = name.trimmedOfAllWhitespaceOrNil,
      !settings.actions.indices.contains(where: { $0 != index && settings.actions[$0].name == name }
      )
    else { return nil }
    let old = settings.actions[index]
    guard name != old.name else { return name }
    let current = currentCopy(of: project)
    let isFileReadable = current.sharedSettingsSnapshot.problem == nil
    let fileActions = current.sharedSettingsSnapshot.confined?.actions ?? []
    // Keys and tabs under a name no action has were left by a dropped row.
    // Unreadable, the file may hold either name, so they stay where they are.
    let isNameLeftOver =
      isFileReadable && !(settings.actions + fileActions).contains { $0.name == name }
    if isNameLeftOver {
      settings.actionShortcuts.set(nil, for: name)
      forgetLeftOverActionTabs(named: name, in: project)
    }
    settings.actions[index] = old.renamed(name)
    let carriesKeysAndTabs =
      isFileReadable
      && !(trustsSharedSettings(of: current) && fileActions.contains { $0.name == old.name })
    if carriesKeysAndTabs { settings.actionShortcuts.rename(old.name, to: name) }
    setSettings(settings, for: project)
    if carriesKeysAndTabs {
      store.renameActionSessions(
        from: old.name,
        to: name,
        in: Set(workspace.worktrees(of: project.id).map(\.id)),
      )
      updateDockBadge()
    }
    noteActionsInForceChanged()
    return name
  }

  public func setActionCommand(_ command: String, at index: Int, in project: Project) {
    var settings = ownSettings(of: project)
    guard settings.actions.indices.contains(index) else { return }
    let old = settings.actions[index]
    settings.actions[index] = old.withCommand(command)
    setSettings(settings, for: project)
    // Per keystroke, so only when the row comes into force or leaves it.
    if settings.actions[index].isFilledIn != old.isFilledIn { noteActionsInForceChanged() }
  }

  /// Its keys go, and its tabs are no action's, unless the file has an action
  /// of its name; a new action of that name would otherwise take them over.
  public func removeAction(at index: Int, from project: Project) {
    var settings = ownSettings(of: project)
    guard settings.actions.indices.contains(index) else { return }
    let removed = settings.actions.remove(at: index)
    let snapshot = currentCopy(of: project).sharedSettingsSnapshot
    let shared = snapshot.confined?.actions ?? []
    // Unreadable, the file may hold the name, so its keys and tabs stay.
    let freesKeysAndTabs =
      snapshot.problem == nil && !(settings.actions + shared).contains { $0.name == removed.name }
    if freesKeysAndTabs { settings.actionShortcuts.set(nil, for: removed.name) }
    setSettings(settings, for: project)
    if freesKeysAndTabs { forgetLeftOverActionTabs(named: removed.name, in: project) }
    noteActionsInForceChanged()
  }

  /// Tabs of a name no action has are no action's, or the next action given
  /// it takes them over, a running server included.
  private func forgetLeftOverActionTabs(named name: String, in project: Project) {
    store.forgetActionSessions(
      named: name,
      in: Set(workspace.worktrees(of: project.id).map(\.id)),
    )
    settlePendingActionRestart()
    updateDockBadge()
  }

  /// The page's order is the play menu's and, on export, the file's.
  public func moveAction(_ id: ProjectAction.ID, to destination: Int, in project: Project) {
    var settings = ownSettings(of: project)
    guard let source = settings.actions.firstIndex(where: { $0.id == id }),
      source != destination, settings.actions.indices.contains(destination)
    else { return }
    settings.actions.insert(settings.actions.remove(at: source), at: destination)
    setSettings(settings, for: project)
  }
}
