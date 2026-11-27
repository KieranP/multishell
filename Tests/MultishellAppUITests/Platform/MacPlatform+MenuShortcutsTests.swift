import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct MacPlatformMenuShortcutsTests {
  private static let nextTabDefault = MenuShortcut(
    command: .nextTab,
    keys: ShortcutCommand.nextTab.defaultCombination,
    isChanged: false,
  )

  private func bar(holding titles: [String]) -> NSMenu {
    let terminal = NSMenu(title: "Terminal")
    for title in titles {
      terminal.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: "x"))
    }
    let bar = NSMenu(title: "")
    let item = NSMenuItem(title: "Terminal", action: nil, keyEquivalent: "")
    item.submenu = terminal
    bar.addItem(item)
    return bar
  }

  @Test func aChangedCommandsItemCarriesItsNewKeysAndAClearedOneNone() throws {
    let menu = bar(holding: [
      ShortcutCommand.splitRight.menuTitle, ShortcutCommand.splitDown.menuTitle,
    ])
    let backslash = KeyCombination(.character("\\"), [.command, .option])

    MacPlatform.setMenuShortcuts(
      [
        MenuShortcut(command: .splitRight, keys: backslash, isChanged: true),
        MenuShortcut(command: .splitDown, keys: nil, isChanged: true),
      ],
      in: menu,
    )

    let items = try #require(menu.items.first?.submenu?.items)
    #expect(items[0].keyEquivalent == "\\")
    #expect(items[0].keyEquivalentModifierMask == [.command, .option])
    #expect(!items[0].allowsAutomaticKeyEquivalentLocalization, "typed on this layout")
    #expect(items[1].keyEquivalent.isEmpty)
    #expect(MenuShortcutText.of(items[0]) == "⌥⌘\\")
  }

  @Test func aMenuMacOSFillsIsLeftAloneEvenWhereAnItemSharesACommandsTitle() throws {
    let services = NSMenu(title: "Services")
    services.addItem(
      NSMenuItem(title: ShortcutCommand.newTab.menuTitle, action: nil, keyEquivalent: "")
    )
    let menu = bar(holding: [])
    let item = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
    item.submenu = services
    menu.addItem(item)

    MacPlatform.setMenuShortcuts(
      [
        MenuShortcut(
          command: .newTab,
          keys: ShortcutCommand.newTab.defaultCombination,
          isChanged: false,
        )
      ],
      in: menu,
      leavingOutMenus: [services],
    )

    #expect(services.items[0].keyEquivalent.isEmpty)
  }

  @Test func aThemeNamedAsACommandKeepsNoKeys() throws {
    let themes = NSMenu(title: ShortcutCommand.nextTab.menuTitle)
    themes.addItem(
      NSMenuItem(title: ShortcutCommand.nextTab.menuTitle, action: nil, keyEquivalent: "")
    )
    let menu = bar(holding: [])
    let terminal = try #require(menu.items.first?.submenu)
    let picker = NSMenuItem(title: MultishellAppUI.t("menu.theme"), action: nil, keyEquivalent: "")
    picker.submenu = themes
    terminal.addItem(picker)

    MacPlatform.setMenuShortcuts([Self.nextTabDefault], in: menu)

    #expect(themes.items[0].keyEquivalent.isEmpty)
  }

  @Test func anActionNamedAsACommandKeepsItsOwnKeys() throws {
    let actions = NSMenu(title: MultishellAppUI.t("menu.actions"))
    actions.addItem(
      NSMenuItem(title: ShortcutCommand.nextTab.menuTitle, action: nil, keyEquivalent: "s")
    )
    let menu = bar(holding: [])
    let terminal = try #require(menu.items.first?.submenu)
    let submenu = NSMenuItem(
      title: MultishellAppUI.t("menu.actions"),
      action: nil,
      keyEquivalent: "",
    )
    submenu.submenu = actions
    terminal.addItem(submenu)

    MacPlatform.setMenuShortcuts([Self.nextTabDefault], in: menu)

    #expect(actions.items[0].keyEquivalent == "s")
  }

  @Test func aDefaultKeepsTheSystemsLayoutLocalization() throws {
    let menu = bar(holding: [ShortcutCommand.nextTab.menuTitle])

    MacPlatform.setMenuShortcuts(
      [Self.nextTabDefault],
      in: menu,
    )

    let item = try #require(menu.items.first?.submenu?.items.first)
    #expect(item.keyEquivalent == "\t")
    #expect(item.keyEquivalentModifierMask == .control)
    #expect(item.allowsAutomaticKeyEquivalentLocalization)
  }
}
