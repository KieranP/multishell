/// How a merge or rebase onto the base ended, where git did not refuse it.
public enum BaseUpdateOutcome: Equatable, Sendable {
  /// Left in progress for someone to resolve, with the paths git could not merge.
  case unfinished(conflictedPaths: [String])
  case updated
}
