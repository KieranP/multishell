import MultishellCore

/// One item of the Terminal menu's Actions submenu: an action's name and keys, without its state,
/// which the bar never shows and so never redraws for.
public struct ActionMenuBarItem: Equatable, Identifiable, Sendable {
  public let name: String
  public let keys: KeyCombination?

  public var id: String { name }
}
