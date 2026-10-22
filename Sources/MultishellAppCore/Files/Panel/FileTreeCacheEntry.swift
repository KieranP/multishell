/// A worktree's tree with what it was built from, so a render that finds
/// none of it moved reuses it, and its last rows for the state they show.
struct FileTreeCacheEntry {
  let sources: FileTreeSources
  let tree: FileTree
  /// Built on the last listing while the sources' own builds, and kept only until it lands.
  var awaitsListing = false
  var rows: (state: FilesPanelState, rows: [FileTreeRow])?
}
