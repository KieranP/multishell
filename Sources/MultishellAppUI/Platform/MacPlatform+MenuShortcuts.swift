import AppKit
import MultishellAppCore
import MultishellCore

/// SwiftUI does not reliably redraw a menu bar's `Commands` (MultishellCommands),
/// so a change of keys is also set on the items here, found by title.
extension MacPlatform {
  /// Services, Window and Help list other apps' and windows' titles, which
  /// may match a command's.
  static func setMenuShortcuts(
    _ shortcuts: [MenuShortcut],
    in menu: NSMenu,
    leavingOut menusMacOSFills: [NSMenu] = [],
  ) {
    let byTitle = Dictionary(
      shortcuts.map { ($0.command.menuTitle, $0) },
      uniquingKeysWith: { first, _ in first },
    )
    setKeys(byTitle, in: menu, leavingOut: menusMacOSFills)
  }

  private static func setKeys(
    _ byTitle: [String: MenuShortcut],
    in menu: NSMenu,
    leavingOut menusMacOSFills: [NSMenu],
  ) {
    for item in menu.items {
      if let submenu = item.submenu {
        // Theme names are the user's own and may match a command's title.
        let isThemePicker = item.title == t("menu.theme")
        guard !isThemePicker, !menusMacOSFills.contains(where: { $0 === submenu }) else { continue }
        setKeys(byTitle, in: submenu, leavingOut: menusMacOSFills)
        continue
      }
      guard let shortcut = byTitle[item.title] else { continue }
      item.keyEquivalent = shortcut.keys.map { String($0.menuKeyCharacter) } ?? ""
      item.keyEquivalentModifierMask = shortcut.keys?.modifiers.modifierFlags ?? []
      item.allowsAutomaticKeyEquivalentLocalization = !shortcut.isChanged
    }
  }

  func setMenuShortcuts(_ shortcuts: [MenuShortcut]) {
    guard let bar = NSApp.mainMenu else { return }
    let menusMacOSFills = [NSApp.servicesMenu, NSApp.windowsMenu, NSApp.helpMenu]
    Self.setMenuShortcuts(shortcuts, in: bar, leavingOut: menusMacOSFills.compactMap(\.self))
  }
}
