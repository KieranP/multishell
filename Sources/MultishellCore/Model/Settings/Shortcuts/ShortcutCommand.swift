/// A menu command whose keys the user may change; `ShortcutGroup` holds the
/// menus' order. The raw value is the state file's key, so it never changes.
public enum ShortcutCommand: String, CaseIterable, Sendable {
  case addProject = "add-project"
  case changesPane = "changes-pane"
  case closeFind = "close-find"
  case closePane = "close-pane"
  case closeTab = "close-tab"
  case copy
  case cut
  case filesPane = "files-pane"
  case find
  case findNext = "find-next"
  case findPrevious = "find-previous"
  case focusNextGroup = "focus-next-group"
  case focusPreviousGroup = "focus-previous-group"
  case moveTabToNewGroup = "move-tab-to-new-group"
  case newAgentTab = "new-agent-tab"
  case newShellTab = "new-shell-tab"
  case newTab = "new-tab"
  case newWorktree = "new-worktree"
  case nextTab = "next-tab"
  case openInEditor = "open-in-editor"
  case paste
  case previousTab = "previous-tab"
  case quickSwitcher = "quick-switcher"
  case quickSwitcherCommands = "quick-switcher-commands"
  case redo
  case reviewPane = "review-pane"
  case selectAll = "select-all"
  case splitDown = "split-down"
  case splitRight = "split-right"
  case toggleAgentBoard = "agents"
  case undo

  /// Every command but the fixed ones: the Shortcuts page's and the command line's.
  public static let changeable = allCases.filter { !$0.isFixed }

  /// Cut, Copy, Paste and Select All. In a pane the same keys are the
  /// engine's own clipboard actions, which the surface keeps.
  public var surfaceKeepsBinding: Bool {
    [.cut, .copy, .paste, .selectAll].contains(self)
  }

  /// The clipboard four, and Undo, Redo and Find, whose keys every Mac app
  /// shares; the owner's choice, Docs/design/shortcuts.md.
  public var isFixed: Bool {
    surfaceKeepsBinding || [.undo, .redo, .find].contains(self)
  }

  public var defaultCombination: KeyCombination {
    switch self {
    case .newTab: .command("t")
    case .newShellTab: .command("t", .shift)
    case .newAgentTab: .command("t", .option)
    case .newWorktree: .command("n")
    case .addProject: .command("o")
    case .openInEditor: .command("o", .shift)
    case .closePane: .command("w")
    case .closeTab: .command("w", .shift)
    case .undo: .command("z")
    case .redo: .command("z", .shift)
    case .cut: .command("x")
    case .copy: .command("c")
    case .paste: .command("v")
    case .selectAll: .command("a")

    // Ghostty binds Cmd+F to a search bar an embedding never shows.
    case .find: .command("f")

    case .findNext: .command("g")
    case .findPrevious: .command("g", .shift)
    case .closeFind: .command("f", .option)

    // Not Cmd+A, which is Select All in a pane and stays there.
    case .toggleAgentBoard: .command("a", .shift)

    case .quickSwitcher: .command("p")
    case .quickSwitcherCommands: .command("p", .shift)

    // Cmd+Shift+F is Ghostty's end-search key, which would end a search under a bar of ours.
    case .filesPane: .command("f", .shift)

    case .changesPane: .command("c", .shift)
    case .reviewPane: .command("r", .shift)
    case .splitRight: .command("d")
    case .splitDown: .command("d", .shift)

    // Not Cmd+Option+D, the system's Dock hiding, which a menu bar never sees.
    case .moveTabToNewGroup: .command("g", .option)

    // Alt and an arrow is word movement in a terminal; Command keeps both steps out of a pane's way.
    case .focusNextGroup: KeyCombination(.rightArrow, [.command, .option])

    case .focusPreviousGroup: KeyCombination(.leftArrow, [.command, .option])
    case .nextTab: KeyCombination(.tab, .control)
    case .previousTab: KeyCombination(.tab, [.control, .shift])
    }
  }
}
