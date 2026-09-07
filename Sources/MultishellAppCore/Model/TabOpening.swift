import Foundation

/// Why a tab is opening, and so which pair of settings decides whether it
/// opens at all and whether it runs the agent rather than a shell.
///
/// A create is asked about apart from a selection throughout: someone
/// triaging worktrees wants a click to look without starting anything, and
/// still wants the worktree they just asked for to come up with an agent
/// already working in it.
public enum TabOpening: Sendable {
  /// New Tab, or a menu item that opens one: the tab was asked for, so it
  /// opens whatever the settings say.
  case byUser
  /// The user turned to a worktree that has no tabs:
  /// `Workspace.opensTerminalOnSelect` and `autoStartAgent`.
  case onSelect
  /// A create, and any post-create hook, has just finished:
  /// `Workspace.opensTerminalOnCreate` and `autoStartAgentOnCreate`, either
  /// of which a project may override.
  case onCreate
  /// The caller is about to open its own tab; nothing opens here.
  case never
}
