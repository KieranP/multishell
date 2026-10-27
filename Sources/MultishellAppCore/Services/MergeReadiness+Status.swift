import MultishellServices

extension MergeReadiness {
  /// The verdict as the CI glyph a run with that outcome would wear: waiting
  /// where only a review, a pending check or its draft state holds it back.
  public var status: CIRunStatus {
    switch verdict {
    case .closed: .cancelled
    case .merged, .ready, .readyWithOptionalFailures: .passed
    case .notReady: blockers.allSatisfy(Self.isWaiting) ? .running : .failed
    }
  }

  private static func isWaiting(_ blocker: Blocker) -> Bool {
    switch blocker {
    case .checksNotRead, .conflictsUnchecked, .draft, .pendingChecks, .reviewRequired: true
    case .behindBase, .blockedByRules, .changesRequested, .conflicts, .failingChecks: false
    }
  }
}
