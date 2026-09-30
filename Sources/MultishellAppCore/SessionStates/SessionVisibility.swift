import MultishellCore

/// `isSeen` is the focused pane and clears a Done; `isOnScreen` is any pane
/// in view and holds the banner. See Docs/design/terminals.md.
struct SessionVisibility {
  var worktreeID: Worktree.ID
  var isSeen: Bool
  var isOnScreen: Bool
}
