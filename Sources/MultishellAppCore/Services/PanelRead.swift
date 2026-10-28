import MultishellCore

/// One worktree's page of the panel, as its reads are logged: each page reads
/// its own, so turning pages mid-read still reads the new one.
struct PanelRead: Hashable, Sendable {
  let worktree: Worktree.ID
  let page: FilesPanelMode
}
