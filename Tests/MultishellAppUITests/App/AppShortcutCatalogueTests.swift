import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite
struct AppShortcutCatalogueTests {
  @Test func aShortcutSpellsItselfForBothTheMenuAndGhostty() {
    #expect(AppShortcutCatalogue.newTab.modifiers == .command)
    #expect(AppShortcutCatalogue.newTab.ghosttyCombo == "super+t")

    #expect(AppShortcutCatalogue.newShellTab.modifiers == [.command, .shift])
    #expect(AppShortcutCatalogue.newShellTab.ghosttyCombo == "super+shift+t")

    #expect(
      AppShortcutCatalogue.newAgentTab.ghosttyCombo == "super+alt+t", "option is alt to Ghostty")

    // Control-only, and a key Ghostty names rather than taking its
    // character: `\t` would be an unparsable keybind.
    #expect(AppShortcutCatalogue.nextTab.modifiers == .control)
    #expect(AppShortcutCatalogue.nextTab.ghosttyCombo == "ctrl+tab")
    #expect(AppShortcutCatalogue.previousTab.ghosttyCombo == "ctrl+shift+tab")

    // Ghostty cannot parse the arrows' private-use scalars, so it names them. Alt
    // and a bare arrow is word movement in a terminal, so these add Command.
    #expect(AppShortcutCatalogue.nextGroup.ghosttyCombo == "super+alt+right")
    #expect(AppShortcutCatalogue.previousGroup.ghosttyCombo == "super+alt+left")
    // Not super+alt+d: the system's Dock toggle, which the
    // WindowServer takes before a menu item can see it.
    #expect(AppShortcutCatalogue.moveTabToNewGroup.ghosttyCombo == "super+alt+g")
    #expect(AppShortcutCatalogue.findPrevious.ghosttyCombo == "super+shift+g")
    #expect(AppShortcutCatalogue.closeFind.ghosttyCombo == "super+shift+f")
  }

  /// Two menu items on one combination is one of them never firing, and
  /// nothing in SwiftUI says which.
  @Test func noTwoShortcutsClaimTheSameKeystroke() {
    let combos = AppShortcutCatalogue.all.map(\.ghosttyCombo)
    #expect(Set(combos).count == combos.count, "\(combos)")
    for combo in combos {
      #expect(
        !GhosttyUnbinds.systemOwned.contains(combo),
        "\(combo) is claimed by both a menu item of ours and the system")
    }
  }
}
