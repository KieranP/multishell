import AppKit
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct MacPlatformCommandMenuItemsTests {
  private static func menu(_ title: String, _ items: [(String, String)]) -> NSMenuItem {
    let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let menu = NSMenu(title: title)
    menu.autoenablesItems = false
    for (name, action) in items {
      menu.addItem(
        NSMenuItem(title: name, action: NSSelectorFromString(action), keyEquivalent: "")
      )
    }
    top.submenu = menu
    return top
  }

  @Test func whatMacOSAddsToTheMenusIsNotACommand() throws {
    let bar = NSMenu()
    let services = Self.menu("Services", [("Look Up in Dictionary", "lookUp:")])
    let app = Self.menu(
      "Multishell",
      [("Settings…", "showSettings:"), ("Hide Multishell", "hide:")],
    )
    try #require(app.submenu).addItem(services)
    bar.addItem(app)
    let edit = Self.menu(
      "Edit",
      [
        (t("menu.undo"), "swiftUIAction:"),
        (t("menu.redo"), "swiftUIAction:"),
        (t("menu.cut"), "swiftUIAction:"),
        (t("action.copy"), "swiftUIAction:"),
        (t("menu.paste"), "swiftUIAction:"),
        (t("menu.select-all"), "swiftUIAction:"),
        ("Contact…", "_handleInsertFromContactsCommand:"),
        ("Start Dictation…", "startDictation:"),
        ("Emoji & Symbols", "orderFrontCharacterPalette:"),
      ],
    )
    try #require(edit.submenu).addItem(
      Self.menu(t("menu.find"), [(t("menu.find-item"), "swiftUIAction:")])
    )
    bar.addItem(edit)
    bar.addItem(
      Self.menu(
        "View",
        [
          ("Files Panel", "toggleFiles:"),
          (t("menu.quick-switcher"), "swiftUIAction:"),
          (t("menu.quick-switcher-commands"), "swiftUIAction:"),
          ("Enter Full Screen", "toggleFullScreen:"),
          ("Show Tab Bar", "toggleTabBar:"),
          ("Show All Tabs", "toggleTabOverview:"),
        ],
      )
    )
    let window = Self.menu("Window", [("Minimize", "performMiniaturize:")])
    let help = Self.menu("Help", [("Multishell Help", "showHelp:")])
    bar.addItem(window)
    bar.addItem(help)

    let items = MacPlatform.commandItems(
      in: bar,
      skippingMenus: [services.submenu, window.submenu, help.submenu].compactMap(\.self),
    )

    #expect(items.map(\.path) == [["Multishell", "Settings…"], ["View", "Files Panel"]])
    #expect(items.map(\.isInAppMenu) == [true, false])
  }

  @Test func aMenuMacOSFillsIsLeftOutThoughTheBarHoldsAnotherCopyOfIt() {
    let bar = NSMenu()
    let app = Self.menu("Multishell", [("Settings…", "showSettings:")])
    app.submenu?.addItem(Self.menu("Services", [("Make New Sticky Note", "makeNote:")]))
    bar.addItem(app)
    let registered = NSMenu(title: "Services")

    let items = MacPlatform.commandItems(in: bar, skippingMenus: [registered])

    #expect(items.map(\.path) == [["Multishell", "Settings…"]])
  }

  @Test func aSubmenuOfTheAppMenuIsMacOSsThoughNoneIsRegistered() {
    let bar = NSMenu()
    let app = Self.menu("Multishell", [("Settings…", "showSettings:")])
    app.submenu?.addItem(Self.menu("Services", [("Show Map", "showMap:")]))
    bar.addItem(app)
    bar.addItem(Self.menu("View", [("Files Panel", "toggleFiles:")]))

    let items = MacPlatform.commandItems(in: bar, skippingMenus: [])

    #expect(items.map(\.path) == [["Multishell", "Settings…"], ["View", "Files Panel"]])
  }

  @Test func theThemePickerIsASettingAndACommandThatCannotActIsLeftOff() {
    let bar = NSMenu()
    bar.addItem(Self.menu("Multishell", [("Settings…", "showSettings:")]))
    let terminal = Self.menu(
      "Terminal",
      [(t("menu.split-right"), "swiftUIAction:"), (t("menu.next-tab"), "swiftUIAction:")],
    )
    terminal.submenu?.addItem(Self.menu(t("menu.theme"), [("Nord", "swiftUIAction:")]))
    bar.addItem(terminal)

    let items = MacPlatform.commandItems(in: bar, skippingMenus: []) { title in
      title != t("menu.next-tab")
    }

    #expect(
      items.map(\.path) == [
        ["Multishell", "Settings…"], ["Terminal", t("menu.split-right")],
        ["Terminal", t("menu.next-tab")],
      ]
    )
    #expect(items.map(\.isEnabled) == [true, true, false])
  }
}
