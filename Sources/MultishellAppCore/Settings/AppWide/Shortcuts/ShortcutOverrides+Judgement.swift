import MultishellCore

extension ShortcutOverrides {
  /// What giving `keys` to `command` would do; Docs/design/shortcuts.md has
  /// the rules and why.
  func judge(_ keys: KeyCombination, for command: ShortcutCommand) -> ShortcutJudgement {
    if command.isFixed { return .refused(.heldByFixed(command)) }
    if let refusal = keys.refusal { return .refused(refusal) }
    if let holder = self.command(holding: keys), holder != command {
      return holder.isFixed ? .refused(.heldByFixed(holder)) : .taken(holder: holder)
    }
    guard !keys.modifiers.contains(.command) else { return .allowed(nil) }
    return .allowed(ShortcutWarning(keys: keys, shellUse: ShellKeyUse(keys)))
  }
}
