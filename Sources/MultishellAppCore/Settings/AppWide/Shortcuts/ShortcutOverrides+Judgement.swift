import MultishellCore

extension ShortcutOverrides {
  private static func allowed(_ keys: KeyCombination) -> ShortcutJudgement {
    guard !keys.modifiers.contains(.command) else { return .allowed(nil) }
    return .allowed(ShortcutWarning(keys: keys, shellUse: ShellKeyUse(keys)))
  }

  /// What giving `keys` to `command` would do; Docs/design/shortcuts.md has
  /// the rules and why.
  func judge(_ keys: KeyCombination, for command: ShortcutCommand) -> ShortcutJudgement {
    if command.isFixed { return .refused(.heldByFixed(command)) }
    if let refusal = keys.refusal { return .refused(refusal) }
    if let holder = self.command(holding: keys), holder != command {
      return holder.isFixed ? .refused(.heldByFixed(holder)) : .taken(holder: holder)
    }
    return Self.allowed(keys)
  }

  /// The same for a project action, which holds no default and never takes
  /// keys from a menu command: those are the menu's, and the menu fires first.
  func judgeForAction(_ keys: KeyCombination) -> ShortcutJudgement {
    if let refusal = keys.refusal { return .refused(refusal) }
    if let holder = command(holding: keys) {
      return holder.isFixed ? .refused(.heldByFixed(holder)) : .taken(holder: holder)
    }
    return Self.allowed(keys)
  }
}
