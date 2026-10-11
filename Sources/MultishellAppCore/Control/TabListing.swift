import Foundation
import MultishellCore

/// What `multishell tabs list` prints: every worktree with its tabs and
/// panes, by the ids the other commands take.
struct TabListing: Encodable, Equatable {
  struct WorktreeTabs: Encodable, Equatable {
    /// Its `ControlID`, as `worktrees list` prints it.
    let id: String
    let name: String
    let isInView: Bool
    let activeTab: TerminalTab.ID?
    let tabs: [Tab]
  }

  struct Tab: Encodable, Equatable {
    let id: TerminalTab.ID
    let title: String
    /// On screen in its group, which a worktree with several groups has
    /// more than one of.
    let isShown: Bool
    let focusedPane: TerminalSession.ID
    let state: SessionState?
    let panes: [Pane]
  }

  struct Pane: Encodable, Equatable {
    let id: TerminalSession.ID
    let title: String
    let isLive: Bool
    let agent: String?
    /// The pane's own dot, `nil` for none: what a script waits on for Done.
    let state: SessionState?
  }

  let worktreeInView: String?
  let worktrees: [WorktreeTabs]
}
