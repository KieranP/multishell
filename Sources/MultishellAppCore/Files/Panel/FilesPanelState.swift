import MultishellCore

/// What the Files panel shows for one worktree. Runtime state, forgotten with
/// the worktree, but for `mode`, which is the saved choice every panel shares.
public struct FilesPanelState: Equatable, Sendable {
  public internal(set) var mode = FilesPanelMode.default
  public internal(set) var filterText = ""
  /// Folders opened in the Files list, which starts with every folder shut.
  var expandedFolders: Set<String> = []
  /// Folders shut in the Changes list, which starts with every folder open.
  var collapsedChangesFolders: Set<String> = []
}
