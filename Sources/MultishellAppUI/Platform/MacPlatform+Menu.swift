import AppKit
import MultishellAppCore

extension MacPlatform {
  /// Walked after each menu validates its items, so enabled means now.
  var menuItems: [PlatformMenuItem] {
    NSApp.mainMenu.map { Self.items(in: $0, under: []) } ?? []
  }

  private static func items(in menu: NSMenu, under path: [String]) -> [PlatformMenuItem] {
    menu.update()
    return menu.items.filter { !$0.isSeparatorItem && !$0.isHidden }.flatMap { item in
      let itemPath = path + [item.title]
      guard let submenu = item.submenu else {
        return [
          PlatformMenuItem(path: itemPath, isEnabled: item.isEnabled, isChecked: item.state == .on)
        ]
      }
      return items(in: submenu, under: itemPath)
    }
  }

  /// The menu holding the leaf `path` names, and the leaf's index in it. A
  /// title matches with or without its trailing ellipsis.
  private static func leaf(at path: [String], in menu: NSMenu) -> (NSMenu, Int)? {
    guard let title = path.first,
      let index = menu.items.firstIndex(where: { item in
        !item.isHidden && withoutEllipsis(item.title) == withoutEllipsis(title)
      })
    else { return nil }
    let item = menu.items[index]
    if path.count == 1 { return item.submenu == nil ? (menu, index) : nil }
    return item.submenu.flatMap { leaf(at: Array(path.dropFirst()), in: $0) }
  }

  private static func withoutEllipsis(_ title: String) -> String {
    var trimmed = title
    for ellipsis in ["…", "..."] where trimmed.hasSuffix(ellipsis) {
      trimmed.removeLast(ellipsis.count)
    }
    return trimmed
  }

  func performMenuItem(_ path: [String]) -> PlatformMenuOutcome {
    guard let menu = NSApp.mainMenu, let (owner, index) = Self.leaf(at: path, in: menu) else {
      return .notFound
    }
    owner.update()
    guard owner.items[index].isEnabled else { return .disabled }
    GhosttySurfaceView.actingForTheCommandLine { owner.performActionForItem(at: index) }
    return .performed
  }
}
