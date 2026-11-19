import MultishellAppCore
import MultishellCore

/// Which model property says a menu command can act, by the item's title,
/// worked out once rather than a lookup per title on each opening.
@MainActor
enum MenuCommandAvailability {
  private static let pairs: [(command: ShortcutCommand, isAvailable: KeyPath<AppModel, Bool>)] = [
    (.newTab, \.canOpenTab),
    (.newShellTab, \.canOpenTab),
    (.newAgentTab, \.canOpenTab),
    (.newWorktree, \.canStartNewWorktree),
    (.openInEditor, \.canOpenWorktreeInEditor),
    (.filesPane, \.canToggleFilesPanel),
    (.changesPane, \.canToggleFilesPanel),
    (.reviewPane, \.canToggleFilesPanel),
    (.closePane, \.hasTabToClose),
    (.closeTab, \.hasTabToClose),
    (.splitRight, \.canSplitPane),
    (.splitDown, \.canSplitPane),
    (.moveTabToNewGroup, \.canMoveActiveTabToNewGroup),
    (.focusNextGroup, \.canFocusAnotherGroup),
    (.focusPreviousGroup, \.canFocusAnotherGroup),
    (.nextTab, \.canActivateAnotherTab),
    (.previousTab, \.canActivateAnotherTab),
  ]

  /// Two titles a translation makes one keep the first, where a literal traps.
  static let byTitle = Dictionary(pairs.map { ($0.command.menuTitle, $0.isAvailable) }) {
    first,
    _ in first
  }
}
