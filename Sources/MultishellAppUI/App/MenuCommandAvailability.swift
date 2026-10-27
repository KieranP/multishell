import MultishellAppCore

/// Which model property says a menu command can act, by the item's title,
/// worked out once rather than a lookup per title on each opening.
@MainActor
enum MenuCommandAvailability {
  private static let pairs: [(String, KeyPath<AppModel, Bool>)] = [
    (t("menu.new-tab"), \.canOpenTab),
    (t("menu.new-shell-tab"), \.canOpenTab),
    (t("menu.new-agent-tab"), \.canOpenTab),
    (t("menu.new-worktree"), \.canStartNewWorktree),
    (t("action.open-in-editor"), \.canOpenWorktreeInEditor),
    (t("menu.files-panel"), \.canToggleFilesPanel),
    (t("menu.close-pane"), \.hasTabToClose),
    (t("menu.close-tab"), \.hasTabToClose),
    (t("menu.split-right"), \.canSplitPane),
    (t("menu.split-down"), \.canSplitPane),
    (t("menu.move-tab-to-new-group"), \.canMoveActiveTabToNewGroup),
    (t("menu.focus-next-group"), \.canFocusAnotherGroup),
    (t("menu.focus-previous-group"), \.canFocusAnotherGroup),
    (t("menu.next-tab"), \.canActivateAnotherTab),
    (t("menu.previous-tab"), \.canActivateAnotherTab),
  ]

  /// Two titles a translation makes one keep the first, where a literal traps.
  static let byTitle = Dictionary(pairs) { first, _ in first }
}
