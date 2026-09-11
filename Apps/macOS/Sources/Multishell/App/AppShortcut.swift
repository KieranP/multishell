import SwiftUI

/// A keyboard shortcut the app owns, in SwiftUI's spelling and Ghostty's,
/// declared once: a combination nobody unbound is dead in a Ghostty pane.
struct AppShortcut {
  let key: KeyEquivalent
  let modifiers: EventModifiers
  /// Whether the surface keeps its own binding rather than giving it up to
  /// the menu bar. True only where Ghostty's action is what a pane wants.
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

  /// The same combination as Ghostty spells it, in the modifier order its
  /// own docs use, so this stays diffable against a config.
  var ghosttyCombo: String {
    var parts: [String] = []
    if modifiers.contains(.command) { parts.append("super") }
    if modifiers.contains(.control) { parts.append("ctrl") }
    if modifiers.contains(.option) { parts.append("alt") }
    if modifiers.contains(.shift) { parts.append("shift") }
    parts.append(Self.ghosttyName(of: key))
    return parts.joined(separator: "+")
  }

  /// Ghostty names a few keys rather than taking their character. The arrows
  /// arrive as the private-use scalars AppKit gives them.
  private static func ghosttyName(of key: KeyEquivalent) -> String {
    switch key.character {
    case "\t": "tab"
    case "\r": "enter"
    case ",": "comma"
    case KeyEquivalent.leftArrow.character: "left"
    case KeyEquivalent.rightArrow.character: "right"
    case KeyEquivalent.upArrow.character: "up"
    case KeyEquivalent.downArrow.character: "down"
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
/// over our windows. The host unbinds and the commands build from these.
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
  /// Not Cmd+Option+D, the system's own toggle for hiding the Dock: the
  /// WindowServer takes it before a menu bar sees it.
  static let moveTabToNewGroup = AppShortcut("g", .option)
  /// Alt and an arrow is word movement in a terminal, which stays bound;
  /// these carry Command as well, so nothing in a pane wants them.
  static let nextGroup = AppShortcut(.rightArrow, .option)
  static let previousGroup = AppShortcut(.leftArrow, .option)
  /// The Agents board, in place of the selected worktree's terminals. Not
  /// Cmd+A, which is Select All in a pane and stays there.
  static let showAgents = AppShortcut("a", .shift)
  static let undo = AppShortcut("z")
  static let redo = AppShortcut("z", .shift)
  static let nextTab = AppShortcut.control(.tab)
  static let previousTab = AppShortcut.control(.tab, .shift)

  /// Copy, paste, cut and select-all. The menu carries them and the surface
  /// keeps them, a pane's Cmd+C being Ghostty's own clipboard action.
  static let cut = AppShortcut("x", surfaceKeeps: true)
  static let copy = AppShortcut("c", surfaceKeeps: true)
  static let paste = AppShortcut("v", surfaceKeeps: true)
  static let selectAll = AppShortcut("a", surfaceKeeps: true)

  /// In declaration order, so `unbound` reads the way the config did. The one
  /// step done by hand: nothing can check a shortcut left out of this list.
  static let all: [AppShortcut] = [
    newTab, newShellTab, newAgentTab, closePane, closeTab, newWorktree,
    addProject, openInEditor, splitRight, splitDown,
    moveTabToNewGroup, nextGroup, previousGroup,
    showAgents, undo, redo, nextTab, previousTab,
    cut, copy, paste, selectAll,
  ]

  /// Combinations the system owns over one of our windows. No menu item of
  /// ours carries these, and the surface must still give them up.
  static let systemOwned = [
    "super+shift+n", "super+comma", "super+q", "super+ctrl+f", "super+enter",
    // Hides the Dock. Listed so nothing here claims it, and so the reason
    // Move Tab to New Group is not on it stays written down.
    "super+alt+d",
  ]

  /// What the terminal surface is told to unbind, or it eats these before
  /// the menu bar sees them.
  static let unbound: [String] =
    all.filter { !$0.surfaceKeeps }.map(\.ghosttyCombo) + systemOwned
}
