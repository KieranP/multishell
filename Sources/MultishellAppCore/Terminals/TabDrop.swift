import MultishellCore

/// Where a dragged tab is released: on a tab, a strip clear of its tabs, a
/// column's terminal area, a band down its edge, or a worktree's row.
public enum TabDrop: Equatable, Sendable {
  case tab(TerminalTab.ID, TerminalTab.Placement)
  case strip(TabGroup.ID)
  case area(TabGroup.ID)
  case band(TabDragState.Band)
  case worktree(Worktree.ID)
}
