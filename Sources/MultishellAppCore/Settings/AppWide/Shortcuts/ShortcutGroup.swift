import MultishellCore

/// A card on the Shortcuts page, the commands a menu lists between two
/// dividers, under the part named for that menu.
public enum ShortcutGroup: CaseIterable, Sendable {
  case agentBoard
  case closeItems
  case filesPanel
  case find
  case groups
  case navigation
  case newItems
  case newTabItems
  case openItems
  case panes
  case pasteboardItems
  case splits
  case tabs
  case undoItems

  public var commands: [ShortcutCommand] {
    switch self {
    case .agentBoard: [.toggleAgentBoard]
    case .closeItems: [.closePane, .closeTab]
    case .filesPanel: [.filesPane, .changesPane, .reviewPane]
    case .find: [.find, .findNext, .findPrevious, .closeFind]
    case .groups: [.moveTabToNewGroup, .focusNextGroup, .focusPreviousGroup]
    case .navigation: [.quickSwitcher, .quickSwitcherCommands, .filterProjects]
    case .newItems: [.newProject, .newWorktree]
    case .newTabItems: [.newTab, .newShellTab, .newAgentTab]
    case .openItems: [.openInEditor]
    case .panes: [.focusNextPane, .focusPreviousPane]
    case .pasteboardItems: [.cut, .copy, .paste, .selectAll]
    case .splits: [.splitRight, .splitDown]
    case .tabs: [.nextTab, .previousTab]
    case .undoItems: [.undo, .redo]
    }
  }

  /// The first card of its part, the only one with a heading row: the cards
  /// below it share its columns.
  public var headsItsPart: Bool {
    SettingsPage.shortcuts.sections(in: .allProjects).contains { section in
      Self.groups(in: section).first == self
    }
  }

  /// The cards of a Shortcuts part, top to bottom as the menu lists them;
  /// none for another section.
  public static func groups(in section: SettingsSection) -> [Self] {
    switch section {
    case .shortcutsFile: [.newItems, .newTabItems, .openItems, .closeItems]
    case .shortcutsEdit: [.undoItems, .pasteboardItems, .find]
    case .shortcutsView: [.agentBoard, .filesPanel, .navigation]
    case .shortcutsTerminal: [.splits, .panes, .tabs, .groups]
    default: []
    }
  }
}
