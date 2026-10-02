import GhosttyTerminal
import Testing

@testable import MultishellAppUI

/// A menu shortcut also needs a `keybind=…=unbind` on the terminal surface, or
/// the surface eats the keystroke before the menu bar sees it.
@Suite
struct GhosttyUnbindsTests {
  @Test func theDerivedUnbindListIsTheOneGhosttyWasAlwaysGiven() {
    #expect(
      Set(GhosttyUnbinds.all) == [
        "super+t", "super+shift+t", "super+alt+t", "super+w", "super+shift+w", "super+n",
        "super+shift+n",
        "super+o", "super+shift+o", "super+d", "super+shift+d", "super+comma", "super+q",
        "super+z", "super+shift+z",
        "super+alt+g", "super+alt+left", "super+alt+right",
        "super+shift+a",
        "super+alt+d",
        "ctrl+tab", "ctrl+shift+tab",
        "super+f", "super+g", "super+shift+g", "super+shift+f",
        "super+ctrl+f", "super+enter",
        "escape",
      ])
  }

  /// Ghostty binds Cmd+F to its own search, whose bar this embedding cannot
  /// show; unbound, the keystroke reaches the Edit menu and ours.
  @Test func theFindShortcutsAreTakenFromTheSurface() {
    let unbound = Set(GhosttyUnbinds.all)
    for shortcut in [
      AppShortcutCatalogue.find, AppShortcutCatalogue.findNext, AppShortcutCatalogue.findPrevious,
      AppShortcutCatalogue.closeFind,
    ] {
      #expect(unbound.contains(shortcut.ghosttyCombo))
    }
    #expect(AppShortcutCatalogue.findPrevious.ghosttyCombo == "super+shift+g")
    #expect(AppShortcutCatalogue.closeFind.ghosttyCombo == "super+shift+f")
  }

  /// One line libghostty cannot parse refuses the whole config, and the unbinds
  /// ride in the theme's: a key name it lacks would cost every colour and the font.
  @MainActor
  @Test func everyUnbindIsALineThePinnedLibghosttyAccepts() {
    let unbinds = GhosttyUnbinds.all.map { "keybind = \($0)=unbind" }
      .joined(separator: "\n")
    let controller = TerminalController(
      configSource: .generated(GhosttyUserConfig.defaults.rendered + "\n" + unbinds))
    #expect(controller.lastConfigurationIssue == nil, "\(controller.lastConfigurationIssue ?? "")")
  }

  /// Ghostty's own `esc=end_search` is performable: while a search runs it eats
  /// Escape in the pane. Released, Escape is a plain key and only the bar ends one.
  @Test func escapeIsReleasedToTheProgramInThePane() {
    #expect(GhosttyUnbinds.surfaceReleases == ["escape"])
    #expect(GhosttyUnbinds.all.contains("escape"))
  }

  /// In a pane Cmd+C is Ghostty's copy of the terminal selection, and unbinding
  /// it sends it to a menu item that has no selection to copy.
  @Test func theClipboardShortcutsStayWithTheTerminal() {
    let unbound = Set(GhosttyUnbinds.all)
    for shortcut in [
      AppShortcutCatalogue.cut, AppShortcutCatalogue.copy, AppShortcutCatalogue.paste,
      AppShortcutCatalogue.selectAll,
    ] {
      #expect(shortcut.surfaceKeeps, "\(shortcut.ghosttyCombo) is the terminal's to handle")
      #expect(!unbound.contains(shortcut.ghosttyCombo))
    }
  }
}
