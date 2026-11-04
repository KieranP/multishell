import AppKit
import MultishellAppCore

extension MacPlatform {
  /// Walked after each menu validates its items, so enabled means now.
  var menuItems: [PlatformMenuItem] {
    NSApp.mainMenu.map { Self.items(in: $0, under: []) } ?? []
  }

  static func items(
    in menu: NSMenu,
    under path: [String],
    isInAppMenu: Bool = false,
    skipping isSkipped: (NSMenuItem) -> Bool = { _ in false },
    isAvailable: (NSMenuItem) -> Bool = { _ in true },
  ) -> [PlatformMenuItem] {
    menu.update()
    let appMenu = path.isEmpty ? menu.items.first : nil
    return menu.items.filter { !$0.isSeparatorItem && !$0.isHidden && !isSkipped($0) }.flatMap {
      item in
      let itemPath = path + [item.title]
      let isInAppMenu = isInAppMenu || item === appMenu
      guard let submenu = item.submenu else {
        return [
          PlatformMenuItem(
            path: itemPath,
            isEnabled: item.isEnabled && isAvailable(item),
            isChecked: item.state == .on,
            shortcut: MenuShortcutText.of(item),
            isInAppMenu: isInAppMenu,
          )
        ]
      }
      return items(
        in: submenu,
        under: itemPath,
        isInAppMenu: isInAppMenu,
        skipping: isSkipped,
        isAvailable: isAvailable,
      )
    }
  }

  /// The menu holding the leaf `path` names, and the leaf's index in it. A
  /// title matches with or without its trailing ellipsis.
  private static func leaf(at path: [String], in menu: NSMenu) -> (NSMenu, Int)? {
    guard let title = path.first,
      let index = menu.items.firstIndex(where: { item in
        !item.isHidden && item.title.withoutTrailingEllipsis == title.withoutTrailingEllipsis
      })
    else { return nil }
    let item = menu.items[index]
    if path.count == 1 { return item.submenu == nil ? (menu, index) : nil }
    return item.submenu.flatMap { leaf(at: Array(path.dropFirst()), in: $0) }
  }

  /// The leaf `path` names, its menu validated now so enabled is current.
  private static func validatedLeaf(at path: [String]) -> (owner: NSMenu, index: Int)? {
    guard let menu = NSApp.mainMenu, let (owner, index) = leaf(at: path, in: menu) else {
      return nil
    }
    owner.update()
    return (owner, index)
  }

  func performMenuItem(_ path: [String]) -> PlatformMenuOutcome {
    guard let (owner, index) = Self.validatedLeaf(at: path) else { return .notFound }
    guard owner.items[index].isEnabled else { return .disabled }
    GhosttySurfaceView.actingForTheCommandLine { owner.performActionForItem(at: index) }
    return .performed
  }

  /// On a timer, as `chooseMenuItem`, then as the command line's own.
  func performMenuItemOnItsTurn(_ path: [String]) async -> PlatformMenuOutcome {
    await withCheckedContinuation { turn in
      Timer.scheduledTimer(withTimeInterval: 0, repeats: false) { _ in turn.resume() }
    }
    return performMenuItem(path)
  }

  /// On a timer, which fires only after the run loop has waited and SwiftUI
  /// has taken the switcher's field down; a queued block ran before that.
  func chooseMenuItem(_ path: [String]) {
    Timer.scheduledTimer(withTimeInterval: 0, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let (owner, index) = Self.validatedLeaf(at: path), owner.items[index].isEnabled
        else {
          self?.beep()
          return
        }
        owner.performActionForItem(at: index)
      }
    }
  }
}
