import MultishellCore

extension ShortcutCommand {
  /// The menu item's title, which the Shortcuts page lists it by and the menu
  /// bar's keys are set against.
  var menuTitle: String {
    switch self {
    case .newTab: t("menu.new-tab")
    case .newShellTab: t("menu.new-shell-tab")
    case .newAgentTab: t("menu.new-agent-tab")
    case .newWorktree: t("menu.new-worktree")
    case .addProject: t("menu.add-project")
    case .openInEditor: t("action.open-in-editor")
    case .closePane: t("menu.close-pane")
    case .closeTab: t("menu.close-tab")
    case .undo: t("menu.undo")
    case .redo: t("menu.redo")
    case .cut: t("menu.cut")
    case .copy: t("action.copy")
    case .paste: t("menu.paste")
    case .selectAll: t("menu.select-all")
    case .find: t("menu.find-item")
    case .findNext: t("menu.find-next")
    case .findPrevious: t("menu.find-previous")
    case .closeFind: t("menu.close-find")
    case .toggleAgentBoard: t("label.agents")
    case .quickSwitcher: t("menu.quick-switcher")
    case .quickSwitcherCommands: t("menu.quick-switcher-commands")
    case .filesPane: t("menu.files-pane")
    case .changesPane: t("menu.changes-pane")
    case .reviewPane: t("menu.review-pane")
    case .splitRight: t("menu.split-right")
    case .splitDown: t("menu.split-down")
    case .moveTabToNewGroup: t("menu.move-tab-to-new-group")
    case .focusNextGroup: t("menu.focus-next-group")
    case .focusPreviousGroup: t("menu.focus-previous-group")
    case .nextTab: t("menu.next-tab")
    case .previousTab: t("menu.previous-tab")
    }
  }
}
