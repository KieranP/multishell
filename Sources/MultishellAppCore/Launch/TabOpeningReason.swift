/// Why a tab is opening, and so which pair of settings decides whether it
/// opens and whether it runs the agent. A create is asked apart throughout.
enum TabOpeningReason: Sendable {
  /// New Tab, or a menu item that opens one: the tab was asked for, so it
  /// opens whatever the settings say.
  case byUser
  /// The user turned to a worktree that has no tabs:
  /// `Workspace.opensTerminalOnSelect` and `autoStartsAgent`.
  case onSelect
  /// A create, and any post-create hook, has just finished:
  /// `opensTerminalOnCreate` and `autoStartsAgentOnCreate`.
  case onCreate
  /// The caller is about to open its own tab; nothing opens here.
  case never
}
