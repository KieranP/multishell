import Foundation

extension ProjectSettings {
  /// The repository's own filling only the gaps the user left, and what it
  /// asks to run or read only once trusted; see Docs/design/settings.md.
  public func layered(over shared: SharedProjectSettings?) -> ProjectSettings {
    // Normalised on both paths, with or without a file to fall through to, or
    // the two disagree over the same stored value.
    var result = self
    result.iconGlyph = ProjectIcon.normalizedGlyph(iconGlyph)
    guard let shared = shared.map(sharedSettingsInForce) else { return result }
    result.branchPrefix = branchPrefix ?? shared.branchPrefix
    result.defaultBranch = defaultBranch ?? shared.defaultBranch
    result.autoStartsAgent = autoStartsAgent ?? shared.autoStartsAgent
    result.autoStartsAgentOnCreate = autoStartsAgentOnCreate ?? shared.autoStartsAgentOnCreate
    result.opensTerminalOnSelect = opensTerminalOnSelect ?? shared.opensTerminalOnSelect
    result.opensTerminalOnCreate = opensTerminalOnCreate ?? shared.opensTerminalOnCreate
    result.worktreeSortOrder = worktreeSortOrder ?? shared.worktreeSortOrder
    result.showsActiveWorktreesFirst =
      showsActiveWorktreesFirst ?? shared.showsActiveWorktreesFirst
    result.iconGlyph = result.iconGlyph ?? ProjectIcon.normalizedGlyph(shared.iconGlyph)
    result.iconTint = iconTint ?? ProjectIcon.usableTint(shared.iconTint)
    result.preCreateHook = preCreateHook.isEmpty ? shared.preCreateHook ?? "" : preCreateHook
    result.postCreateHook = postCreateHook.isEmpty ? shared.postCreateHook ?? "" : postCreateHook
    result.preDeleteHook = preDeleteHook.isEmpty ? shared.preDeleteHook ?? "" : preDeleteHook
    result.postDeleteHook = postDeleteHook.isEmpty ? shared.postDeleteHook ?? "" : postDeleteHook
    result.linkedPaths = linkedPaths.isEmpty ? shared.linkedPaths ?? "" : linkedPaths
    result.copiedPaths = copiedPaths.isEmpty ? shared.copiedPaths ?? "" : copiedPaths
    result.worktreeDirectory = worktreeDirectory ?? shared.worktreeDirectory
    return result
  }

  /// The project's value where it has one, the default otherwise.
  func effectiveWorktreeSettings(defaults: WorktreeSettings) -> WorktreeSettings {
    WorktreeSettings(
      worktreeDirectory: worktreeDirectory?.trimmingCharacters(in: .whitespaces)
        ?? defaults.worktreeDirectory,
      branchPrefix: branchPrefix?.trimmingCharacters(in: .whitespaces) ?? defaults.branchPrefix
    )
  }
}
