import MultishellCore

/// Keys without ⌘, which every pane gives up to the menu, and what the shell
/// used them for where it is known.
public struct ShortcutWarning: Hashable, Sendable {
  public let keys: KeyCombination
  public let shellUse: ShellKeyUse?
}
