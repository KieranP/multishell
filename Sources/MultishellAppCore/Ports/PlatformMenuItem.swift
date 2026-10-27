/// One item of the menu bar as `multishell ui menu` lists it.
public struct PlatformMenuItem: Encodable, Equatable, Sendable {
  // `ui menu` lists what the bar shows; which menu is the app's is the switcher's.
  private enum CodingKeys: String, CodingKey {
    case path, isEnabled, isChecked, shortcut
  }

  /// Its titles from the bar down: `["View", "Enable Debug Tools"]`.
  let path: [String]
  let isEnabled: Bool
  /// Ticked, as a toggle that is on is.
  let isChecked: Bool
  /// Its keys as the menu draws them, `⇧⌘P`; `nil` for an item without.
  let shortcut: String?
  /// In the menu named for the app, which the switcher calls the application's.
  let isInAppMenu: Bool

  public init(
    path: [String],
    isEnabled: Bool,
    isChecked: Bool,
    shortcut: String? = nil,
    isInAppMenu: Bool = false,
  ) {
    self.path = path
    self.isEnabled = isEnabled
    self.isChecked = isChecked
    self.shortcut = shortcut
    self.isInAppMenu = isInAppMenu
  }
}
