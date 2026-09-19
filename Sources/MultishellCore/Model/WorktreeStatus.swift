import Foundation

/// What `git status` says about a worktree right now. Runtime only, so no
/// stale badge survives a relaunch.
public struct WorktreeStatus: Hashable, Sendable {
  public var staged = 0
  public var unstaged = 0
  public var untracked = 0
  public var conflicted = 0
  public var ahead = 0
  public var behind = 0

  /// Files with any change. A file that is both staged and modified counts
  /// once, because it is one line of `git status`.
  public var changedFiles = 0

  /// Lines added and removed against HEAD, with an untracked file's whole
  /// contents counted as added; see Docs/design/worktrees.md.
  public var insertions = 0
  public var deletions = 0
  /// Files that changed with no line to show for it: a binary file, a mode
  /// change, a rename, an untracked file too big or too odd to read.
  public var unscoredFiles = 0

  /// The branch git reports, or nil when detached. Compared against the
  /// sidebar so a checkout made in a terminal shows up without a watcher.
  public var branch: String?

  public init() {}

  public var isDirty: Bool { changedFiles > 0 }
  public var isClean: Bool { changedFiles == 0 && ahead == 0 && behind == 0 }

  /// One line for a tooltip: "3 changed · 1 untracked · ↑2".
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
}
