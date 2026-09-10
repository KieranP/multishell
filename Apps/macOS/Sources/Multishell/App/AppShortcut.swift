import SwiftUI

/// A keyboard shortcut the app owns, in both spellings it needs.
///
/// SwiftUI's, for the menu item, and Ghostty's, for the `keybind=…=unbind`
/// that usually has to accompany it: Ghostty's defaults bind most of these
/// to actions this embedding cannot perform, and the surface consumes the
/// keystroke before the menu bar sees it. Declared once so the two cannot
/// drift — a menu item whose combination nobody unbound is a shortcut that
/// does nothing in a Ghostty pane and works everywhere else.
struct AppShortcut {
  let key: KeyEquivalent
  let modifiers: EventModifiers
  /// Whether the surface keeps its own binding for this combination rather
  /// than giving it up to the menu bar. True only where Ghostty's action is
  /// the terminal-local one and is what the user wants in a pane.
  let surfaceKeeps: Bool

  init(_ key: KeyEquivalent, _ extra: EventModifiers = [], surfaceKeeps: Bool = false) {
    self.key = key
    self.modifiers = extra.union(.command)
    self.surfaceKeeps = surfaceKeeps
  }

  /// Control-only, for the tab cycling that does not take Command.
  static func control(_ key: KeyEquivalent, _ extra: EventModifiers = []) -> AppShortcut {
    AppShortcut(key: key, modifiers: extra.union(.control), surfaceKeeps: false)
  }

  private init(key: KeyEquivalent, modifiers: EventModifiers, surfaceKeeps: Bool) {
    self.key = key
    self.modifiers = modifiers
    self.surfaceKeeps = surfaceKeeps
  }

  /// The same combination as Ghostty spells it. Modifier order is the one
  /// its own docs use; its parser takes any, but a stable order keeps this
  /// diffable against a config.
  var ghosttyCombo: String {
    var parts: [String] = []
    if modifiers.contains(.command) { parts.append("super") }
    if modifiers.contains(.control) { parts.append("ctrl") }
    if modifiers.contains(.option) { parts.append("alt") }
    if modifiers.contains(.shift) { parts.append("shift") }
    parts.append(Self.ghosttyName(of: key))
    return parts.joined(separator: "+")
  }

  /// Ghostty names a few keys rather than taking their character.
  private static func ghosttyName(of key: KeyEquivalent) -> String {
    switch key.character {
    case "\t": "tab"
    case "\r": "enter"
    case ",": "comma"
    default: String(key.character)
    }
  }
}

extension View {
  /// Attaches both halves of a shortcut's contract: the menu item's
  /// equivalent here, and the surface's unbind through `AppShortcuts`.
  func keyboardShortcut(_ shortcut: AppShortcut) -> some View {
    keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
  }
}

/// Every keystroke this app's menus claim, and the ones the system claims
/// over a window of ours. `GhosttyTerminalHost` unbinds what this says to;
/// `MultishellCommands` builds its items from the same values.
enum AppShortcuts {
  static let newTab = AppShortcut("t")
  static let newShellTab = AppShortcut("t", .shift)
  static let newAgentTab = AppShortcut("t", .option)
  static let newWorktree = AppShortcut("n")
  static let addProject = AppShortcut("o")
  static let openInEditor = AppShortcut("o", .shift)
  static let closePane = AppShortcut("w")
  static let closeTab = AppShortcut("w", .shift)
  static let splitRight = AppShortcut("d")
  static let splitDown = AppShortcut("d", .shift)
  static let undo = AppShortcut("z")
  static let redo = AppShortcut("z", .shift)
  static let nextTab = AppShortcut.control(.tab)
  static let previousTab = AppShortcut.control(.tab, .shift)

  /// Copy, paste, cut and select-all. The menu carries them, and the
  /// surface keeps them: in a pane these are Ghostty's own clipboard
  /// actions on the terminal's selection, which is what the user means by
  /// Cmd+C there. Unbound, Cmd+C would reach a menu item that sends
  /// `NSText.copy(_:)` to a responder with no selection to give.
  static let cut = AppShortcut("x", surfaceKeeps: true)
  static let copy = AppShortcut("c", surfaceKeeps: true)
  static let paste = AppShortcut("v", surfaceKeeps: true)
  static let selectAll = AppShortcut("a", surfaceKeeps: true)

  /// In declaration order, so `unbound` reads the way the config did.
  ///
  /// The one step still done by hand: a shortcut declared above but left
  /// out here is unbound nowhere, and works everywhere but a Ghostty pane.
  /// Nothing can check it — Swift cannot enumerate an enum's static members
  /// and SwiftUI cannot be asked what its menus bound.
  static let all: [AppShortcut] = [
    newTab, newShellTab, newAgentTab, closePane, closeTab, newWorktree,
    addProject, openInEditor, splitRight, splitDown,
    undo, redo, nextTab, previousTab,
    cut, copy, paste, selectAll,
  ]

  /// Combinations the system owns over one of our windows: New Window,
  /// Settings, Quit, the fullscreen shortcut and the one that enters it
  /// from a split. No menu item of ours carries these, and the surface must
  /// still give them up.
  static let systemOwned = [
    "super+shift+n", "super+comma", "super+q", "super+ctrl+f", "super+enter",
  ]

  /// What the terminal surface is told to unbind, or it eats these before
  /// the menu bar sees them.
  static let unbound: [String] =
    all.filter { !$0.surfaceKeeps }.map(\.ghosttyCombo) + systemOwned
}
