import MultishellGitKit

/// Everything a worktree's tree is built from, compared whole so a render
/// that finds none of it moved reuses the tree.
struct FileTreeSources: Equatable, Sendable {
  var tracked = TrackedFiles.empty
  var status: WorktreeStatus?
  /// The opened submodules' own tracked files and status, by their path.
  var submodules: [String: SubmoduleReading] = [:]
  /// What git ignores, a wholly ignored folder as one entry ending in `/`.
  var ignoredEntries: [String] = []
  /// The read ignored folders' entries, open or shut, by the folder's path.
  var ignoredFolderEntries: [String: [IgnoredFolderEntry]] = [:]
}
