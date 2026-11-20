import MultishellCore
import Testing

@testable import MultishellAppUI

/// A menu shortcut also needs a `keybind=…=unbind` on the terminal surface, or
/// the surface eats the keystroke before the menu bar sees it.
@Suite
struct GhosttyUnbindsTests {
  private let defaults = ShortcutCommand.allCases.filter { !$0.surfaceKeepsBinding }
    .map(\.defaultCombination)

  @Test func theDefaultsUnbindWhatGhosttyWasAlwaysGivenAndTheWholeReservedTable() {
    #expect(
      Set(GhosttyUnbinds.all(unbinding: defaults)) == [
        "super+t", "super+key_t", "super+shift+t", "super+shift+key_t", "super+alt+t",
        "super+alt+key_t", "super+w", "super+key_w", "super+shift+w", "super+shift+key_w",
        "super+n", "super+key_n", "super+shift+n", "super+shift+key_n", "super+o", "super+key_o",
        "super+shift+o", "super+shift+key_o", "super+d", "super+key_d", "super+shift+d",
        "super+shift+key_d", "super+,", "super+comma", "super+q", "super+key_q", "super+z",
        "super+key_z", "super+shift+z", "super+shift+key_z", "super+alt+g", "super+alt+key_g",
        "super+alt+left", "super+alt+right", "super+shift+a", "super+shift+key_a", "super+p",
        "super+key_p", "super+shift+p", "super+shift+key_p", "super+shift+c", "super+shift+key_c",
        "super+shift+r", "super+shift+key_r", "super+alt+f", "super+alt+key_f", "super+alt+d",
        "super+alt+key_d", "ctrl+tab", "ctrl+shift+tab", "super+f", "super+key_f", "super+g",
        "super+key_g", "super+shift+g", "super+shift+key_g", "super+shift+f", "super+shift+key_f",
        "super+ctrl+f", "super+ctrl+key_f", "super+enter", "super+h", "super+key_h", "super+alt+h",
        "super+alt+key_h", "super+m", "super+key_m", "super+tab", "super+space", "super+`",
        "super+backquote", "super+shift+\\", "super+shift+backslash", "super+shift+/",
        "super+shift+slash", "super+shift+q", "super+shift+key_q", "super+alt+shift+q",
        "super+alt+shift+key_q",
        "super+ctrl+q", "super+ctrl+key_q", "super+shift+3", "super+shift+digit_3",
        "super+shift+4", "super+shift+digit_4", "super+shift+5", "super+shift+digit_5", "ctrl+left",
        "ctrl+right", "ctrl+up", "ctrl+down", "super+alt+space", "ctrl+space", "ctrl+alt+space",
        "super+ctrl+space", "super+shift+tab", "super+shift+`", "super+shift+backquote", "super+.",
        "super+period", "super+ctrl+shift+3", "super+ctrl+shift+digit_3", "super+ctrl+shift+4",
        "super+ctrl+shift+digit_4", "super+alt+m", "super+alt+key_m", "super+f5", "super+alt+f5",
        "super+ctrl+d",
        "super+ctrl+key_d", "super+]", "super+bracket_right", "super+[", "super+bracket_left",
        "super+alt+p", "super+alt+key_p", "escape",
      ]
    )
  }

  /// Ghostty binds Cmd+F to its own search, whose bar this embedding cannot
  /// show; unbound, the keystroke reaches the Edit menu and ours.
  @Test func theFindShortcutsAreTakenFromTheSurface() {
    let unbound = Set(GhosttyUnbinds.all(unbinding: defaults))
    for command in [ShortcutCommand.find, .findNext, .findPrevious, .closeFind] {
      #expect(unbound.isSuperset(of: command.defaultCombination.ghosttyTriggers))
    }
  }

  @Test func anOverridesKeysAreUnboundAlongsideTheDefaults() {
    let backslash = KeyCombination(.character("\\"), .command)

    let unbound = GhosttyUnbinds.all(unbinding: defaults + [backslash])

    #expect(unbound.contains("super+\\"))
    #expect(unbound.contains("super+backslash"))
  }

  /// libghostty drops a line it refuses without a word, so a key name it lacks
  /// would leave that shortcut to Ghostty rather than the menu.
  @Test func everyUnbindIsALineThePinnedLibghosttyAccepts() throws {
    let unbinds = GhosttyUnbinds.all(unbinding: defaults).map { "keybind = \($0)=unbind" }
      .joined(separator: "\n")
    let diagnostics = try libghosttyDiagnostics(
      GhosttyUserConfig.defaults.rendered + "\n" + unbinds
    )
    #expect(diagnostics.isEmpty, "\(diagnostics)")
  }

  /// Ghostty's own `esc=end_search` is performable: while a search runs it eats
  /// Escape in the pane. Released, Escape is a plain key and only the bar ends one.
  @Test func escapeIsReleasedToTheProgramInThePane() {
    #expect(GhosttyUnbinds.surfaceReleases == ["escape"])
    #expect(GhosttyUnbinds.all(unbinding: []).contains("escape"))
  }

  /// In a pane Cmd+C is Ghostty's copy of the terminal selection, and unbinding
  /// it sends it to a menu item that has no selection to copy.
  @Test func theClipboardShortcutsStayWithTheTerminal() {
    let unbound = Set(GhosttyUnbinds.all(unbinding: defaults))
    for command in ShortcutCommand.allCases where command.surfaceKeepsBinding {
      #expect(unbound.isDisjoint(with: command.defaultCombination.ghosttyTriggers), "\(command)")
    }
  }
}
