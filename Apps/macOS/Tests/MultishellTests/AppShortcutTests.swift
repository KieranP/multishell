import SwiftUI
import Testing

@testable import Multishell

/// The two halves of a keyboard shortcut: the menu item's equivalent and the
/// `keybind=…=unbind` the terminal surface needs, or the surface eats the
/// keystroke before the menu bar sees it. They were two lists that had to be
/// kept in step by hand; these pin what the one list now derives.
@Suite
struct AppShortcutTests {
  /// The combinations the surface is told to give up, exactly as the
  /// hand-written config listed them before they were derived. This is the
  /// assertion that says the change to one source altered nothing.
  @Test func theDerivedUnbindListIsTheOneGhosttyWasAlwaysGiven() {
    #expect(
      Set(AppShortcuts.unbound) == [
        "super+t", "super+shift+t", "super+alt+t", "super+w", "super+shift+w", "super+n",
        "super+shift+n",
        "super+o", "super+shift+o", "super+d", "super+shift+d", "super+comma", "super+q",
        "super+z", "super+shift+z",
        "ctrl+tab", "ctrl+shift+tab",
        "super+ctrl+f", "super+enter",
      ])
  }

  /// The deliberate exception, pinned so it is not "fixed". In a pane these
  /// are Ghostty's own clipboard actions on the terminal's selection, which
  /// is what Cmd+C means there; unbinding them sends it to a menu item that
  /// has no selection to copy.
  @Test func theClipboardShortcutsStayWithTheTerminal() {
    let unbound = Set(AppShortcuts.unbound)
    for shortcut in [
      AppShortcuts.cut, AppShortcuts.copy, AppShortcuts.paste,
      AppShortcuts.selectAll,
    ] {
      #expect(shortcut.surfaceKeeps, "\(shortcut.ghosttyCombo) is the terminal's to handle")
      #expect(!unbound.contains(shortcut.ghosttyCombo))
    }
  }

  @Test func aShortcutSpellsItselfForBothTheMenuAndGhostty() {
    #expect(AppShortcuts.newTab.modifiers == .command)
    #expect(AppShortcuts.newTab.ghosttyCombo == "super+t")

    #expect(AppShortcuts.newShellTab.modifiers == [.command, .shift])
    #expect(AppShortcuts.newShellTab.ghosttyCombo == "super+shift+t")

    #expect(AppShortcuts.newAgentTab.ghosttyCombo == "super+alt+t", "option is alt to Ghostty")

    // Control-only, and a key Ghostty names rather than taking its
    // character: `\t` would be an unparsable keybind.
    #expect(AppShortcuts.nextTab.modifiers == .control)
    #expect(AppShortcuts.nextTab.ghosttyCombo == "ctrl+tab")
    #expect(AppShortcuts.previousTab.ghosttyCombo == "ctrl+shift+tab")
  }

  /// Two menu items on one combination is one of them never firing, and
  /// nothing in SwiftUI says which.
  @Test func noTwoShortcutsClaimTheSameKeystroke() {
    let combos = AppShortcuts.all.map(\.ghosttyCombo)
    #expect(Set(combos).count == combos.count, "\(combos)")
    for combo in combos {
      #expect(
        !AppShortcuts.systemOwned.contains(combo),
        "\(combo) is claimed by both a menu item of ours and the system")
    }
  }
}
