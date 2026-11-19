import MultishellCore

/// A card on the Shortcuts page, the commands a menu lists between two
/// dividers, under the part named for that menu.
public enum ShortcutGroup: CaseIterable, Sendable {
  case closeItems
  case editing
  case filesPanel
  case find
  case groups
  case newItems
  case panes
  case show
  case tabs

  public var commands: [ShortcutCommand] {
    switch self {
    case .closeItems: [.closePane, .closeTab]
    case .editing: [.undo, .redo, .cut, .copy, .paste, .selectAll]
    case .filesPanel: [.filesPane, .changesPane, .reviewPane]
    case .find: [.find, .findNext, .findPrevious, .closeFind]
    case .groups: [.moveTabToNewGroup, .focusNextGroup, .focusPreviousGroup]
    case .newItems: [.newTab, .newShellTab, .newAgentTab, .newWorktree, .addProject, .openInEditor]
    case .panes: [.splitRight, .splitDown]
    case .show: [.toggleAgentBoard, .quickSwitcher, .quickSwitcherCommands]
    case .tabs: [.nextTab, .previousTab]
    }
  }

  /// The cards of a Shortcuts part, top to bottom as the menu lists them;
  /// none for another section.
  public static func groups(in section: SettingsSection) -> [Self] {
    switch section {
    case .shortcutsFile: [.newItems, .closeItems]
    case .shortcutsEdit: [.editing, .find]
    case .shortcutsView: [.show, .filesPanel]
    case .shortcutsTerminal: [.panes, .groups, .tabs]
    default: []
    }
  }
}
