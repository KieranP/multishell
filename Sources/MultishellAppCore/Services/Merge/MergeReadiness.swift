import MultishellServices

/// Whether a pull request can merge, and what holds it back: its draft
/// state, conflicts, checks, review and base.
struct MergeReadiness: Equatable, Sendable {
  /// What holds a pull request back.
  enum Blocker: Equatable, Sendable {
    case behindBase
    case blockedByRules
    case changesRequested
    /// The checks are being read, or no read has answered.
    case checksNotRead
    case conflicts
    /// The host has not yet worked out whether it conflicts.
    case conflictsUnchecked
    case draft
    case failingChecks
    case pendingChecks
    case reviewRequired
  }

  let blockers: [Blocker]
  /// In the host's order; `nil` until a read answers.
  let checks: [PullRequestCheck]?
  let mergeAction: MergeAction?

  /// `checks` is `nil` until a read answers: none read is not none failing.
  init(_ pullRequest: PullRequest, checks: [PullRequestCheck]?) {
    let blockers = Self.blockers(of: pullRequest, checks: checks)
    self.blockers = blockers
    mergeAction = Self.mergeAction(of: pullRequest, blockers: blockers)
    self.checks = checks
  }

  private static func blockers(
    of pullRequest: PullRequest,
    checks: [PullRequestCheck]?,
  ) -> [Blocker] {
    var blockers: [Blocker] = []
    let listed = checks ?? []
    if pullRequest.state == .draft { blockers.append(.draft) }
    if pullRequest.blocker == .conflicts { blockers.append(.conflicts) }
    if !pullRequest.hasConflictAnswer { blockers.append(.conflictsUnchecked) }
    if listed.contains(where: { $0.isRequired && $0.status == .failed }) {
      blockers.append(.failingChecks)
    }
    switch pullRequest.review {
    case .changesRequested: blockers.append(.changesRequested)
    case .required: blockers.append(.reviewRequired)
    case .approved, .notRequired: break
    }
    if listed.contains(where: { $0.isRequired && $0.status.isUnderWay }) {
      blockers.append(.pendingChecks)
    }
    if checks == nil { blockers.append(.checksNotRead) }
    if pullRequest.blocker == .behindBase { blockers.append(.behindBase) }
    // The host's own word, where nothing above accounts for it: a rule this
    // build does not read, such as signed commits.
    if pullRequest.blocker == .blocked, blockers.isEmpty { blockers.append(.blockedByRules) }
    return blockers
  }
}
