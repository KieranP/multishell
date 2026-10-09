import MultishellCore

/// Where a dragged tab is released: on a tab, a strip clear of its tabs, a
/// group's terminal area, a band down its edge, or a worktree's row.
public enum TabDrop: Equatable, Sendable {
  case area(TabGroup.ID)
  case band(TabGroupBand)
  case strip(TabGroup.ID)
  case tab(TerminalTab.ID, TerminalTab.Placement)
  case worktree(Worktree.ID)
}
