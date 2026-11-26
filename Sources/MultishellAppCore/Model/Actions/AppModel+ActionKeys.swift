import MultishellCore

/// The keys an action is given and what the panes give up to them; judged
/// as Settings > Shortcuts judges a command's (Docs/design/actions.md).
extension AppModel {
  /// The keys of a project's actions in force, which alone the panes give up:
  /// a row with no command, or a file's action deleted or untrusted, runs nothing.
  func actionKeysInForce(of project: Project) -> [KeyCombination] {
    let shortcuts = project.settings.actionShortcuts
    return effectiveSettings(for: project).actions.filter(\.isFilledIn).compactMap { action in
      shortcuts.keys(for: action.name)
    }
  }

  /// Sets the keys where the Shortcuts page's judge allows them, `nil` being
  /// none. Keys a menu command holds are refused here, never taken from it.
  @discardableResult
  func setActionKeys(
    _ keys: KeyCombination?,
    forAction name: String,
    in project: Project,
  ) -> ShortcutJudgement {
    let judgement = keys.map(judgeActionKeys) ?? .allowed(nil)
    guard judgement.isAllowed else { return judgement }
    var settings = ownSettings(of: project)
    settings.actionShortcuts.set(keys, for: name)
    setSettings(settings, for: project)
    applyTerminalConfiguration()
    return judgement
  }

  /// The keys cell's clear button: no keys, which every judge allows.
  public func clearActionKeys(forAction name: String, in project: Project) {
    setActionKeys(nil, forAction: name, in: project)
  }

  /// What a pane gives up to an action's keys, said under its row.
  func actionKeysWarning(forAction name: String, in project: Project) -> ShortcutWarning? {
    guard let keys = ownSettings(of: project).actionShortcuts.keys(for: name),
      case .allowed(let warning) = judgeActionKeys(keys)
    else { return nil }
    return warning
  }

  private func judgeActionKeys(_ keys: KeyCombination) -> ShortcutJudgement {
    workspace.shortcutOverrides.judgeForAction(keys)
  }
}
