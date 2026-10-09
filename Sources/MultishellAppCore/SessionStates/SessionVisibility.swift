import MultishellCore

/// `isSeen` is the focused pane and clears a Done; `isOnScreen` is any pane
/// in view and holds the banner. See Docs/design/terminals.md.
struct SessionVisibility {
  let worktreeID: Worktree.ID
  let isSeen: Bool
  let isOnScreen: Bool
}
