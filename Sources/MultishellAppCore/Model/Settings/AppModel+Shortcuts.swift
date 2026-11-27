import MultishellCore

extension AppModel {
  public var hasChangedShortcuts: Bool {
    !workspace.shortcutOverrides.isEmpty
  }

  /// Every command's default and override but those the pane keeps. A freed
  /// default is unbound too, or Ghostty's own binding, ⌘F's search, takes it.
  var surfaceUnbinds: [KeyCombination] {
    let overrides = workspace.shortcutOverrides
    let commandKeys = ShortcutCommand.allCases.filter { !$0.surfaceKeepsBinding }.flatMap {
      command in
      var keys = [command.defaultCombination]
      if case .keys(let override) = overrides[command] { keys.append(override) }
      return keys
    }
    // Every project's, whichever worktree is in view.
    let actionKeys = workspace.projects.flatMap(actionKeysInForce)
    return commandKeys + Set(actionKeys).sorted { $0.spelled < $1.spelled }
  }

  /// The keys in force for the command, `nil` for none.
  public func shortcutKeys(for command: ShortcutCommand) -> KeyCombination? {
    workspace.shortcutOverrides.keys(for: command)
  }

  /// The command whose change took this one's default, which leaves it none,
  /// as a later build's new default can; `nil` where it has its keys.
  public func commandHoldingDefault(of command: ShortcutCommand) -> ShortcutCommand? {
    guard !isShortcutChanged(command) else { return nil }
    let holder = workspace.shortcutOverrides.command(holding: command.defaultCombination)
    return holder == command ? nil : holder
  }

  public func menuShortcut(for command: ShortcutCommand) -> MenuShortcut {
    MenuShortcut(
      command: command,
      keys: shortcutKeys(for: command),
      isChanged: isShortcutChanged(command),
    )
  }

  public func isShortcutChanged(_ command: ShortcutCommand) -> Bool {
    workspace.shortcutOverrides[command] != nil
  }

  /// The commands changed in a Shortcuts part, for its sidebar row.
  public func changedShortcutCount(in section: SettingsSection) -> Int {
    ShortcutGroup.groups(in: section).flatMap(\.commands).count(where: isShortcutChanged)
  }

  private func judgeShortcut(
    _ keys: KeyCombination,
    for command: ShortcutCommand,
  )
    -> ShortcutJudgement
  {
    workspace.shortcutOverrides.judge(keys, for: command)
  }

  /// What a pane gives up to a changed command's keys, said under its row
  /// for as long as the change stands.
  public func shortcutWarning(for command: ShortcutCommand) -> ShortcutWarning? {
    guard case .keys(let keys) = workspace.shortcutOverrides[command],
      case .allowed(let warning) = judgeShortcut(keys, for: command)
    else { return nil }
    return warning
  }

  /// Sets the keys where the judge allows them, `nil` being none, which only a
  /// fixed command refuses. The answer says what stopped it otherwise.
  @discardableResult
  func setShortcut(
    _ keys: KeyCombination?,
    for command: ShortcutCommand,
  )
    -> ShortcutJudgement
  {
    guard let keys else {
      guard !command.isFixed else { return .refused(.heldByFixed(command)) }
      changeShortcutOverrides { $0.set(.noKeys, for: command) }
      return .allowed(nil)
    }
    let judgement = judgeShortcut(keys, for: command)
    if case .allowed = judgement {
      changeShortcutOverrides { $0.set(.keys(keys), for: command) }
    }
    return judgement
  }

  /// Sets the keys, leaving the command that held them with none: the answer
  /// to `taken`. Nothing where the judge refuses them outright.
  func replaceShortcut(_ keys: KeyCombination, for command: ShortcutCommand) {
    switch judgeShortcut(keys, for: command) {
    case .refused: break
    case .allowed: changeShortcutOverrides { $0.set(.keys(keys), for: command) }

    case .taken(let holder):
      changeShortcutOverrides { overrides in
        overrides.set(.noKeys, for: holder)
        overrides.set(.keys(keys), for: command)
      }
    }
  }

  /// Drops the command's change, never asking: a default another command now
  /// holds leaves it none rather than shared.
  func followDefaultShortcut(_ command: ShortcutCommand) {
    changeShortcutOverrides { $0.set(nil, for: command) }
  }

  public func restoreDefaultShortcuts() {
    changeShortcutOverrides { $0 = ShortcutOverrides() }
  }

  private func changeShortcutOverrides(_ change: (inout ShortcutOverrides) -> Void) {
    var overrides = workspace.shortcutOverrides
    change(&overrides)
    guard overrides != workspace.shortcutOverrides else { return }
    store.setShortcutOverrides(overrides)
    endShortcutsPageEdit()
    applyTerminalConfiguration()
    platform.setMenuShortcuts(ShortcutCommand.allCases.map(menuShortcut))
  }
}
