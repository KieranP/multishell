/// A worktree's tree with what it was built from, so a render that finds
/// none of it moved reuses it, and its last rows for the state they show.
struct FileTreeCacheEntry {
  let sources: FileTreeSources
  let tree: FileTree
  var rows: (state: FilesPanelState, rows: [FileTreeRow])?
}
