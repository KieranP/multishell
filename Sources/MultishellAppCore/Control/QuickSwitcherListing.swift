import MultishellCore

/// What `multishell ui switcher` prints: the quick switcher's sections and
/// rows as `quickSwitcherResults` hands them to the view.
struct QuickSwitcherListing: Encodable, Equatable {
  struct Section: Encodable, Equatable {
    /// `waiting`, `recent`, `places`, `files`, `changed-files`, `commands`,
    /// `worktrees`, `tabs` or `agents`.
    let kind: String
    /// The worktree a `files` or `changed-files` section lists.
    let worktreeName: String?
    /// The state an `agents` section gathers.
    let state: SessionState?
    let rows: [Row]
  }

  struct Row: Encodable, Equatable {
    /// `agent`, `command`, `file`, `file-tab`, `project`, `shell` or `worktree`.
    let kind: String
    let title: String
    let location: String
    let state: SessionState?
    /// A command's keys, as its menu item draws them.
    let shortcut: String?
    /// Where Return lands.
    let isSelected: Bool
  }

  let scope: String
  let text: String
  let sections: [Section]
  /// `no-match`, `nothing-to-list` or `reading-files` where no row is listed.
  let emptyReason: String?
}
