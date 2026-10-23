/// A worktree's tree with what it was built from, so a render that finds
/// none of it moved reuses it, and its last rows for the state they show.
struct FileTreeCacheEntry {
  let sources: FileTreeSources
  let tree: FileTree
  /// Built on the last listing while the sources' own builds, kept until it lands.
  var awaitsListing = false
  /// Built on the last change set while the sources' own builds, as `awaitsListing`.
  var awaitsChanges = false
  var rows: (state: FilesPanelState, rows: [FileTreeRow])?
}
