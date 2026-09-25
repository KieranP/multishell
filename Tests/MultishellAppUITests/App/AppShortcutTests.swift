import GhosttyTerminal
import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

/// A menu shortcut also needs a `keybind=…=unbind` on the terminal surface, or
/// the surface eats the keystroke before the menu bar sees it.
@Suite
struct AppShortcutTests {
  @Test func theDerivedUnbindListIsTheOneGhosttyWasAlwaysGiven() {
    #expect(
      Set(AppShortcuts.unbound) == [
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
    let unbound = Set(AppShortcuts.unbound)
    for shortcut in [
      AppShortcuts.find, AppShortcuts.findNext, AppShortcuts.findPrevious, AppShortcuts.closeFind,
    ] {
      #expect(unbound.contains(shortcut.ghosttyCombo))
    }
    #expect(AppShortcuts.findPrevious.ghosttyCombo == "super+shift+g")
    #expect(AppShortcuts.closeFind.ghosttyCombo == "super+shift+f")
  }

  /// One line libghostty cannot parse refuses the whole config, and the unbinds
  /// ride in the theme's: a key name it lacks would cost every colour and the font.
  @MainActor
  @Test func everyUnbindIsALineThePinnedLibghosttyAccepts() {
    let unbinds = AppShortcuts.unbound.map { "keybind = \($0)=unbind" }.joined(separator: "\n")
    let controller = TerminalController(
      configSource: .generated(GhosttyUserConfig.defaults.rendered + "\n" + unbinds))
    #expect(controller.lastConfigurationIssue == nil, "\(controller.lastConfigurationIssue ?? "")")
  }

  /// The same for the whole app layer, which carries the unbinds and now
  /// the four search colours: every built-in theme, rendered and offered.
  @MainActor
  @Test func everyBuiltInThemesConfigurationIsOneThePinnedLibghosttyAccepts() {
    for theme in Theme.builtins {
      let rendered = GhosttyAppLayer.configuration(theme, Appearance()).rendered
      #expect(rendered.contains("search-background = #"), "\(theme.name)")
      #expect(rendered.contains("search-selected-background = #"), "\(theme.name)")
      // Match text is the dark one of the pair: a light theme's background is
      // near white, and white on yellow cannot be read.
      let text = (theme.isDark ? theme.backgroundRGB : theme.foregroundRGB).hex
      #expect(rendered.contains("search-foreground = \(text)"), "\(theme.name)")
      #expect(rendered.contains("search-selected-foreground = \(text)"), "\(theme.name)")
      let controller = TerminalController(configSource: .generated(rendered))
      #expect(
        controller.lastConfigurationIssue == nil,
        "\(theme.name): \(controller.lastConfigurationIssue ?? "")")
    }
  }

  /// Ghostty's own `esc=end_search` is performable: while a search runs it eats
  /// Escape in the pane. Released, Escape is a plain key and only the bar ends one.
  @Test func escapeIsReleasedToTheProgramInThePane() {
    #expect(AppShortcuts.surfaceReleases == ["escape"])
    #expect(AppShortcuts.unbound.contains("escape"))
  }

  /// In a pane Cmd+C is Ghostty's copy of the terminal selection, and unbinding
  /// it sends it to a menu item that has no selection to copy.
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

    // Ghostty cannot parse the arrows' private-use scalars, so it names them. Alt
    // and a bare arrow is word movement in a terminal, so these add Command.
    #expect(AppShortcuts.nextGroup.ghosttyCombo == "super+alt+right")
    #expect(AppShortcuts.previousGroup.ghosttyCombo == "super+alt+left")
    // Not super+alt+d: the system's Dock toggle, which the
    // WindowServer takes before a menu item can see it.
    #expect(AppShortcuts.moveTabToNewGroup.ghosttyCombo == "super+alt+g")
    #expect(AppShortcuts.systemOwned.contains("super+alt+d"))
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
