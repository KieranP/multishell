import MultishellCore

/// A command's menu item keys as the menu bar is given them.
public struct MenuShortcut: Equatable, Sendable {
  public let command: ShortcutCommand
  /// `nil` for none, the item staying.
  public let keys: KeyCombination?
  /// Typed on this layout by the user, so no layout localisation may move them.
  public let isChanged: Bool
}
