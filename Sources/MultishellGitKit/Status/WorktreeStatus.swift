import MultishellCore

/// What `git status` says about a worktree right now. Runtime only, so no
/// stale badge survives a relaunch.
public struct WorktreeStatus: Hashable, Sendable {
  var staged = 0
  var unstaged = 0
  var untracked = 0
  var conflicted = 0
  public internal(set) var ahead = 0
  public internal(set) var behind = 0

  /// Files with any change, every new file in a new folder among them,
  /// whichever indicator is set. A file both staged and modified counts once.
  public internal(set) var changedFiles = 0

  /// What the badge counts, an entry a path or two where git lists it twice;
  /// its lines are the sums of these. Under Staged Only, the index alone.
  public internal(set) var changes: [StatusChange] = []
  /// New files by path, whatever the indicator, at most
  /// `WorktreeGit.listedPathLimit` of the `untracked` counted.
  public internal(set) var untrackedPaths: [String] = []

  /// Lines added and removed against HEAD, with an untracked file's whole
  /// contents counted as added; see Docs/design/worktrees.md.
  public internal(set) var insertions = 0
  public internal(set) var deletions = 0
  /// Files that changed with no line to show for it: a binary file, a mode
  /// change, an untracked file too big or too odd to read.
  public internal(set) var unscoredFiles = 0

  /// The branch git reports, or nil when detached. Compared against the
  /// sidebar, which catches a checkout no file event reports.
  public internal(set) var branch: String?

  /// New files counted but not listed by path.
  public var unlistedUntrackedFiles: Int { max(0, untracked - untrackedPaths.count) }

  public var isDirty: Bool { changedFiles > 0 }
  public var isCleanAndInSync: Bool { changedFiles == 0 && ahead == 0 && behind == 0 }

  /// One line for a tooltip: "+12 −3 · 2 modified · 1 untracked · ↑2".
  public var summary: String {
    var parts: [String] = []
    if isDirty { parts.append(t("status.lines", insertions, deletions)) }
    if unscoredFiles > 0 { parts.append(t("status.unscored", unscoredFiles)) }
    if staged > 0 { parts.append(t("status.staged", staged)) }
    if unstaged > 0 { parts.append(t("status.modified", unstaged)) }
    if untracked > 0 { parts.append(t("status.untracked", untracked)) }
    if conflicted > 0 { parts.append(t("status.conflicted", conflicted)) }
    if ahead > 0 { parts.append(t("status.ahead", ahead)) }
    if behind > 0 { parts.append(t("status.behind", behind)) }
    return parts.isEmpty ? t("status.clean") : parts.joined(separator: " · ")
  }

  init() {}

  mutating func setChanges(_ changes: [StatusChange]) {
    self.changes = changes
    let counts = LineCounts(summing: changes.map(\.lines))
    insertions = counts.insertions
    deletions = counts.deletions
    unscoredFiles = counts.unscoredFiles
  }
}
