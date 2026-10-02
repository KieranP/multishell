import MultishellCore

/// A worktree's sidebar row and the pane rows under it, read once for both
/// the rows and the block height, which must agree.
public struct SidebarWorktree: Identifiable, Sendable {
  public let worktree: Worktree
  public let customName: String?
  public let isRenaming: Bool
  public let panes: [SidebarPane]

  public var id: Worktree.ID { worktree.id }
  public var hasCustomName: Bool { customName != nil }

  /// None where the pane rows list the terminals, which would say it twice.
  public func shownTerminalCount(of total: Int) -> Int {
    panes.isEmpty ? total : 0
  }
}
