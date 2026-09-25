import SwiftUI

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
  static let toggleAgentBoard = AppShortcut("a", .shift)
  static let undo = AppShortcut("z")
  static let redo = AppShortcut("z", .shift)
  static let nextTab = AppShortcut.control(.tab)
  static let previousTab = AppShortcut.control(.tab, .shift)
  /// Ghostty binds Cmd+F to a search bar of its own that an embedding never
  /// shows; taken from the surface so the keystroke reaches ours.
  static let find = AppShortcut("f")
  static let findNext = AppShortcut("g")
  static let findPrevious = AppShortcut("g", .shift)
  /// Ghostty's own end-search key, which would otherwise end a search under
  /// a bar of ours that stayed up.
  static let closeFind = AppShortcut("f", .shift)

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
    toggleAgentBoard, undo, redo, nextTab, previousTab,
    find, findNext, findPrevious, closeFind,
    cut, copy, paste, selectAll,
  ]

  /// Hides the Dock. Listed so nothing here claims it, and so the reason Move
  /// Tab to New Group is not on it stays written down.
  private static let dockToggle = "super+alt+d"

  /// Combinations the system owns over one of our windows. No menu item of
  /// ours carries these, and the surface must still give them up.
  static let systemOwned = [
    "super+shift+n", "super+comma", "super+q", "super+ctrl+f", "super+enter", dockToggle,
  ]

  /// Ghostty bindings on plain keys, released so the key reaches the program:
  /// its performable `esc=end_search` ate Escape under our bar; terminals.md.
  static let surfaceReleases = ["escape"]

  /// What the terminal surface is told to unbind, or it eats these before
  /// the menu bar sees them.
  static let unbound: [String] =
    all.filter { !$0.surfaceKeeps }.map(\.ghosttyCombo) + systemOwned + surfaceReleases
}
