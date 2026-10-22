/// Changed lines summed over files, and the changed files with no line to
/// show: a binary file, a mode change, an unreadable file.
struct LineCounts: Equatable, Sendable {
  private(set) var insertions = 0
  private(set) var deletions = 0
  private(set) var unscoredFiles = 0

  init(summing lines: some Sequence<StatusChange.Lines>) {
    for fileLines in lines {
      switch fileLines {
      case .counted(let added, let removed):
        insertions += added
        deletions += removed

      case .notCounted: break

      case .unscored: unscoredFiles += 1
      }
    }
  }
}
