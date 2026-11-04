import MultishellServices

extension MergeReadiness {
  /// Checks not yet read, beside GitHub's UNKNOWN at most: nothing holds it
  /// back for good, but nothing says yet whether to wait.
  var awaitsChecksRead: Bool {
    blockers.contains(.checksNotRead)
      && blockers.allSatisfy { $0 == .checksNotRead || $0 == .conflictsUnchecked }
  }

  /// Merge only where the card reads ready, whatever GitHub's own CLEAN says;
  /// Merge When Ready where only machines hold it back, checks or GitHub's UNKNOWN.
  static func mergeAction(of pullRequest: PullRequest, blockers: [Blocker]) -> MergeAction? {
    guard pullRequest.state == .open else { return nil }
    if pullRequest.autoMergesWhenReady { return .cancelAutoMerge }
    if blockers.isEmpty { return .merge }
    let waitsOnMachinesAlone = blockers.allSatisfy { blocker in
      if case .pendingChecks = blocker { return true }
      return blocker == .conflictsUnchecked
    }
    return waitsOnMachinesAlone ? .mergeWhenReady : nil
  }
}
