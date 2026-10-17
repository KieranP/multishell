import MultishellCore

/// A folder the panel reads itself rather than from git's listing: an opened
/// ignored folder from disk, or an expanded submodule as a repository.
struct PanelFolderRead: Hashable {
  enum Kind {
    case ignoredFolder
    case submodule
  }

  let kind: Kind
  let path: String
  let worktreeID: Worktree.ID
}
