import AppKit
import MultishellAppCore

/// The app's own commands that can act now, for the quick switcher; what is
/// left out and why is in Docs/design/quick-switcher/lists-and-matching.md.
extension MacPlatform {
  /// Hide and Show All, Dictation, Emoji & Symbols, Enter Full Screen and the
  /// window tabbing items.
  private static let actionsMacOSAdds: Set<String> = [
    "hide:", "hideOtherApplications:", "unhideAllApplications:", "startDictation:",
    "orderFrontCharacterPalette:", "toggleFullScreen:", "toggleTabBar:", "toggleTabOverview:",
  ]
  /// AutoFill's items call private selectors of this stem.
  private static let autoFillActionStem = "_handleInsertFrom"
  /// Editing every app has, Find, the theme picker and the switcher's own two.
  /// SwiftUI buttons all share one action, so their own titles tell them apart.
  private static let ownItemsLeftOut: Set<String> = [
    t("menu.undo"), t("menu.redo"), t("menu.cut"), t("action.copy"), t("menu.paste"),
    t("menu.select-all"), t("menu.find"), t("menu.theme"), t("menu.quick-switcher"),
    t("menu.quick-switcher-commands"),
  ]

  /// A switch's title names a state, which reads wrong in a row with no unticked box.
  private static let switcherTitles = [
    t("menu.show-hidden-files"): t("quick-switcher.toggle-hidden-files")
  ]

  var commandMenuItems: [PlatformMenuItem] {
    let menusMacOSFills = [NSApp.servicesMenu, NSApp.windowsMenu, NSApp.helpMenu]
    let isAvailable = isCommandAvailable ?? { _ in true }
    return NSApp.mainMenu.map { bar in
      Self.commandItems(
        in: bar,
        leavingOutMenus: menusMacOSFills.compactMap(\.self),
        isAvailable: isAvailable,
      )
    } ?? []
  }

  static func commandItems(
    in bar: NSMenu,
    leavingOutMenus: [NSMenu],
    isAvailable: (String) -> Bool = { _ in true },
  ) -> [PlatformMenuItem] {
    let appMenu = bar.items.first?.submenu
    return items(
      in: bar,
      under: [],
      leavingOut: { isLeftOut($0, appMenu: appMenu, leavingOutMenus: leavingOutMenus) },
      isAvailable: { isAvailable($0.title) },
      switcherTitle: { switcherTitles[$0.title] },
    )
  }

  private static func isLeftOut(
    _ item: NSMenuItem,
    appMenu: NSMenu?,
    leavingOutMenus: [NSMenu],
  ) -> Bool {
    if ownItemsLeftOut.contains(item.title) { return true }
    if let submenu = item.submenu {
      // The app menu's own are About, Settings and Quit; any submenu is Services.
      if let appMenu, item.menu === appMenu { return true }
      // SwiftUI rebuilds the bar, which can hold a copy of the menu registered.
      return leavingOutMenus.contains { $0 === submenu || $0.title == submenu.title }
    }
    guard let action = item.action.map(NSStringFromSelector) else { return false }
    return actionsMacOSAdds.contains(action) || action.hasPrefix(autoFillActionStem)
  }
}
