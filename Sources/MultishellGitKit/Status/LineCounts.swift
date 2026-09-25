/// A worktree's changed lines, and the changed files with no line to show:
/// a binary file, a mode change, a pure rename, an unreadable file.
struct LineCounts: Equatable, Sendable {
  var insertions = 0
  var deletions = 0
  var unscored = 0
}
