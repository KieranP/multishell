/// A worktree's tree with what it was built from, so a render that finds
/// none of it moved reuses it, and its last rows for the state they show.
struct FileTreeCacheEntry {
  let sources: FileTreeSources
  let tree: FileTree
  /// Built on the last listing while the sources' own builds, kept until it lands.
  let awaitsListing: Bool
  /// Built on the last change set while the sources' own builds, as `awaitsListing`.
  let awaitsChanges: Bool
  var rows: (state: FilesPanelState, rows: [FileTreeRow])?
  /// The quick switcher's last search over `tree`'s listing, carried to the
  /// next entry while that listing holds and let go with it.
  var quickSwitcherSearch: QuickSwitcherFileSearch?
}
