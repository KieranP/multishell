import MultishellCore

/// What `multishell sidebar list` prints: the rows as the sidebar draws them,
/// filtered, in each project's order, a collapsed project's rows left out.
struct SidebarRowListing: Encodable, Equatable {
  struct ProjectRow: Encodable, Equatable {
    let id: String
    let name: String
    let isExpanded: Bool
    /// The dot the row stands in with for its worktrees, collapsed.
    let state: SessionState?
    let worktrees: [WorktreeRow]
  }

  struct WorktreeRow: Encodable, Equatable {
    let id: String
    let name: String
    let isRenaming: Bool
    let isAutoRenaming: Bool
    /// Why the last Auto Rename left the name, until the row's warning is clicked.
    let autoRenameFailure: String?
    let isInView: Bool
    let state: SessionState?
    /// The count the row shows, none where its pane rows list them.
    let terminalCount: Int
    let panes: [PaneRow]
  }

  struct PaneRow: Encodable, Equatable {
    let id: TerminalSession.ID
    let title: String
    let isFocused: Bool
    let state: SessionState?
    let agent: String?
  }

  let filterText: String
  let projects: [ProjectRow]
  /// What the list says in place of rows, `nil` while it shows some.
  let emptyMessage: String?
}
