import MultishellServices

/// Whether a pull request can merge, and each thing that decides it: its
/// review, conflicts and checks, as the SCM panel lists them.
public struct MergeReadiness: Equatable, Sendable {
  enum Verdict: Equatable, Sendable {
    case closed
    case merged
    case notReady
    case ready
    /// Every requirement holds, but a check nobody required failed.
    case readyWithOptionalFailures
  }

  /// What holds a pull request back, most pressing first.
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
    case failingChecks(Int)
    case pendingChecks(Int)
    case reviewRequired
  }

  /// Who a blocker that is only a wait is waiting on: a machine finishes on its
  /// own, a person perhaps days later, as a CI run on hold does.
  enum Waiter {
    case machine
    case person
  }

  /// A row of the panel's list: a review or conflict requirement, or a check.
  public struct Requirement: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      case check(PullRequestCheck)
      case conflicts
      case review
    }

    public let kind: Kind
    public let status: CIRunStatus
    let isRequired: Bool

    /// The review and conflict rows are required by nature, so only a check
    /// says it.
    public var showsRequiredTag: Bool {
      guard isRequired, case .check = kind else { return false }
      return true
    }

    /// A conflict wears the design's warning rather than a failed check's cross.
    public var warnsOfConflicts: Bool { kind == .conflicts && status == .failed }
  }

  let verdict: Verdict
  let blockers: [Blocker]
  public let requirements: [Requirement]
  let mergeAction: MergeAction?

  /// `checks` is `nil` until a read answers: none read is not none failing.
  init(_ pullRequest: PullRequest, checks: [PullRequestCheck]?) {
    let blockers = Self.blockers(of: pullRequest, checks: checks)
    self.blockers = blockers
    mergeAction = Self.mergeAction(of: pullRequest, blockers: blockers)
    requirements = Self.requirements(of: pullRequest, checks: checks)
    verdict =
      switch pullRequest.state {
      case .closed: .closed

      case .merged: .merged

      case .draft, .open:
        if !blockers.isEmpty {
          .notReady
        } else if checks?.contains(where: { !$0.isRequired && $0.status == .failed }) == true {
          .readyWithOptionalFailures
        } else {
          .ready
        }
      }
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
    let failing = listed.filter { $0.isRequired && $0.status == .failed }.count
    if failing > 0 { blockers.append(.failingChecks(failing)) }
    switch pullRequest.review {
    case .changesRequested: blockers.append(.changesRequested)
    case .required: blockers.append(.reviewRequired)
    case .approved, .notRequired: break
    }
    let pending = listed.filter { $0.isRequired && $0.status.isUnderWay }.count
    if pending > 0 { blockers.append(.pendingChecks(pending)) }
    if checks == nil { blockers.append(.checksNotRead) }
    if pullRequest.blocker == .behindBase { blockers.append(.behindBase) }
    // The host's own word, where nothing above accounts for it: a rule this
    // build does not read, such as signed commits.
    if pullRequest.blocker == .blocked, blockers.isEmpty { blockers.append(.blockedByRules) }
    return blockers
  }

  /// The review and the conflicts as rows of their own, then the required
  /// checks, then the rest, each group in the host's order.
  private static func requirements(
    of pullRequest: PullRequest,
    checks: [PullRequestCheck]?,
  ) -> [Requirement] {
    let checks = checks ?? []
    var rows: [Requirement] = []
    let reviewStatus: CIRunStatus? =
      switch pullRequest.review {
      case .approved: .passed
      case .changesRequested: .failed
      case .required: .onHold
      case .notRequired: nil
      }
    if let reviewStatus {
      rows.append(Requirement(kind: .review, status: reviewStatus, isRequired: true))
    }
    // A merged or closed one has nothing left to merge, and GitHub stops
    // working its conflicts out, answering UNKNOWN for good.
    if pullRequest.state == .open || pullRequest.state == .draft {
      rows.append(
        Requirement(kind: .conflicts, status: conflictsStatus(of: pullRequest), isRequired: true)
      )
    }
    let ordered = checks.filter(\.isRequired) + checks.filter { !$0.isRequired }
    rows += ordered.map { check in
      Requirement(kind: .check(check), status: check.status, isRequired: check.isRequired)
    }
    return rows
  }

  private static func conflictsStatus(of pullRequest: PullRequest) -> CIRunStatus {
    if pullRequest.blocker == .conflicts { return .failed }
    return pullRequest.hasConflictAnswer ? .passed : .running
  }
}
