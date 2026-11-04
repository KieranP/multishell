import MultishellServices

extension MergeReadiness {
  /// The verdict as the CI glyph a run with that outcome would wear: running
  /// while a machine works it out, on hold where only a person holds it back.
  public var status: CIRunStatus {
    switch verdict {
    case .closed: .cancelled
    case .merged, .ready, .readyWithOptionalFailures: .passed
    case .notReady: notReadyStatus
    }
  }

  /// Failed where a blocker is wrong rather than a wait; else whose wait it is.
  private var notReadyStatus: CIRunStatus {
    let waiters = blockers.map(Self.waiter(of:))
    if waiters.contains(nil) { return .failed }
    return waiters.contains(.machine) ? .running : .onHold
  }

  /// `nil` for a blocker that is wrong rather than only a wait.
  private static func waiter(of blocker: Blocker) -> Waiter? {
    switch blocker {
    case .checksNotRead, .conflictsUnchecked, .pendingChecks: .machine
    case .draft, .reviewRequired: .person
    case .behindBase, .blockedByRules, .changesRequested, .conflicts, .failingChecks: nil
    }
  }
}
