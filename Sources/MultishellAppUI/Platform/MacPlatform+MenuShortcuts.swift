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
    leavingOutMenus menusMacOSFills: [NSMenu] = [],
  ) {
    let byTitle = Dictionary(keepingFirst: shortcuts.map { ($0.command.menuTitle, $0) })
    setKeys(byTitle, in: menu, leavingOutMenus: menusMacOSFills)
  }

  private static func setKeys(
    _ byTitle: [String: MenuShortcut],
    in menu: NSMenu,
    leavingOutMenus menusMacOSFills: [NSMenu],
  ) {
    for item in menu.items {
      if let submenu = item.submenu {
        // Theme and action names are the user's own and may match a command's title.
        let isNamedByUser = item.title == t("menu.theme") || item.title == t("menu.actions")
        guard !isNamedByUser, !menusMacOSFills.contains(where: { $0 === submenu }) else { continue }
        setKeys(byTitle, in: submenu, leavingOutMenus: menusMacOSFills)
        continue
      }
      guard let shortcut = byTitle[item.title] else { continue }
      item.setKeys(shortcut.keys, isChanged: shortcut.isChanged)
    }
  }

  func setMenuShortcuts(_ shortcuts: [MenuShortcut]) {
    guard let bar = NSApp.mainMenu else { return }
    Self.setMenuShortcuts(shortcuts, in: bar, leavingOutMenus: Self.menusMacOSFills)
  }
}
