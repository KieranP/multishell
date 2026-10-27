import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct MenuShortcutTextTests {
  private static func item(_ key: String, _ modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
    let item = NSMenuItem(title: "Item", action: nil, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    return item
  }

  @Test func modifiersReadInTheMenusOwnOrderBeforeTheKey() {
    let item = Self.item("p", [.command, .shift, .option, .control])

    #expect(MenuShortcutText.of(item) == "⌃⌥⇧⌘P")
  }

  @Test func anUppercaseKeyCarriesShiftWithoutTheFlag() {
    #expect(MenuShortcutText.of(Self.item("P", .command)) == "⇧⌘P")
  }

  @Test func anArrowOrTabIsDrawnAsItsSymbol() {
    #expect(MenuShortcutText.of(Self.item("\u{F703}", [.command, .option])) == "⌥⌘→")
    #expect(MenuShortcutText.of(Self.item("\t", .control)) == "⌃⇥")
  }

  @Test func aFunctionKeyAndTheEditingKeysAreNamed() {
    #expect(MenuShortcutText.of(Self.item("\u{F708}", .command)) == "⌘F5")
    #expect(MenuShortcutText.of(Self.item("\u{F728}", .command)) == "⌘⌦")
    #expect(MenuShortcutText.of(Self.item("\u{F72C}", [])) == "⇞")
  }

  @Test func enterIsNamedAndAKeyWithNoNameShowsNoShortcut() {
    #expect(MenuShortcutText.of(Self.item("\u{3}", .command)) == "⌘⌤")
    #expect(MenuShortcutText.of(Self.item("\u{F746}", .command)) == nil)
  }

  @Test func anItemWithoutAKeyHasNoShortcut() {
    #expect(MenuShortcutText.of(Self.item("", .command)) == nil)
  }
}
