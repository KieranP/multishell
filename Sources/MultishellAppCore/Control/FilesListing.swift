import MultishellCore

/// What `multishell files list` prints: the Files panel's page and its rows,
/// as `fileTreeRows` hands them to the view.
struct FilesListing: Encodable, Equatable {
  struct Row: Encodable, Equatable {
    /// Relative to the worktree; a merged chain of folders is its last.
    let path: String
    let name: String
    /// Where a filtered file sits; `nil` in the tree.
    let parentFolder: String?
    let depth: Int
    let isFolder: Bool
    let isExpanded: Bool
    /// `added`, `deleted` or `modified`; `nil` for one unchanged.
    let change: String?
    let insertions: Int?
    let deletions: Int?
    let isIgnored: Bool
    /// Its file's tab is in front of the focused group, as the row is lit.
    let isShown: Bool
  }

  /// Its worktree's `ControlID`.
  let worktree: String
  /// `files` or `git`, as `filesPanelMode` names them.
  let page: String
  /// Modified or Branch, on the `git` page alone.
  let changeScope: ChangeScope?
  let filterText: String
  /// git's list, its status, the branch's changes, an opened folder or the tree is
  /// still being read or built, the rows the last.
  let isReading: Bool
  let rows: [Row]
}
