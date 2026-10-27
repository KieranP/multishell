/// Why the quick switcher lists nothing, which its view words.
public enum QuickSwitcherEmptyReason: Equatable, Sendable {
  case noMatch
  case nothingToList
  /// The selected worktree's files are still being read or listed.
  case readingFiles
}
