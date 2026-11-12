import MultishellCore
import MultishellServices

/// The pull request page's steps toward a merge, in the order it draws them,
/// then where the path ends; see Docs/design/services/merge-path.md.
public struct MergePath: Equatable, Sendable {
  public struct Step: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      case behindBase
      case blockedByRules
      case checks
      /// Being read, or the read failed with none read before it.
      case checksNotRead
      case conflicts
      case draft
      case review
    }

    public let kind: Kind
    public let status: CIRunStatus

    /// A conflict wears the design's warning rather than a failed check's cross.
    public var warnsOfConflicts: Bool { kind == .conflicts && status == .failed }
  }

  public enum End: Equatable, Sendable {
    case closed
    case merged(isOutgrown: Bool)
    case offers(MergeAction)
    /// The host took a merge the list does not show yet, so nothing is offered.
    case taken
    /// A disabled Merge, and what it waits on.
    case waits(Wait)
  }

  public enum Wait: Equatable, Sendable {
    /// Only machines are left, Multishell's read of the checks among them,
    /// under way or failed.
    case checksRead
    case steps(Int)
  }

  public let steps: [Step]
  /// Every check in the host's order; `nil` until a read answers.
  public let checks: [PullRequestCheck]?
  public let end: End
  /// Why the checks' last read failed.
  let checksReadProblem: String?

  /// A failed read after one that answered is said under the card; one with
  /// none answered is the checks step's own.
  public var staleChecksNote: String? {
    guard let checks, let checksReadProblem else { return nil }
    return checks.isEmpty
      ? t("merge-path.not-read-again", checksReadProblem)
      : t("merge-path.stale-checks", checksReadProblem)
  }

  init(
    _ pullRequest: PullRequest,
    readiness: MergeReadiness,
    isMergeTaken: Bool,
    isOutgrown: Bool,
    checksReadProblem: String?,
  ) {
    let steps = Self.steps(of: pullRequest, readiness: readiness)
    self.steps = steps
    checks = readiness.checks
    self.checksReadProblem = checksReadProblem
    end =
      switch pullRequest.state {
      case .closed: .closed

      case .merged: .merged(isOutgrown: isOutgrown)

      case .draft, .open:
        if isMergeTaken {
          .taken
        } else if let action = readiness.mergeAction {
          .offers(action)
        } else {
          .waits(Self.wait(readiness: readiness, steps: steps))
        }
      }
  }

  private static func steps(of pullRequest: PullRequest, readiness: MergeReadiness) -> [Step] {
    var steps: [Step] = []
    // A merged or closed one has nothing left to merge, though GitHub still
    // answers it BLOCKED or BEHIND, and its conflicts UNKNOWN for good.
    let isOpen = !pullRequest.state.isSettled
    if pullRequest.state == .draft { steps.append(Step(kind: .draft, status: .onHold)) }
    if isOpen { steps.append(Step(kind: .conflicts, status: conflictsStatus(of: pullRequest))) }
    if isOpen, readiness.blockers.contains(.behindBase) {
      steps.append(Step(kind: .behindBase, status: .failed))
    }
    if let checks = readiness.checks {
      if !checks.isEmpty { steps.append(Step(kind: .checks, status: checksStatus(of: checks))) }
    } else {
      steps.append(Step(kind: .checksNotRead, status: .running))
    }
    if let review = reviewStatus(of: pullRequest) {
      steps.append(Step(kind: .review, status: review))
    }
    if isOpen, readiness.blockers.contains(.blockedByRules) {
      steps.append(Step(kind: .blockedByRules, status: .failed))
    }
    return steps
  }

  private static func conflictsStatus(of pullRequest: PullRequest) -> CIRunStatus {
    if pullRequest.blocker == .conflicts { return .failed }
    return pullRequest.hasConflictAnswer ? .passed : .running
  }

  /// As the verdict weighs them: only a required check holds it back.
  private static func checksStatus(of checks: [PullRequestCheck]) -> CIRunStatus {
    let required = checks.filter(\.isRequired)
    if required.contains(where: { $0.status == .failed }) { return .failed }
    return required.contains(where: \.status.isUnderWay) ? .running : .passed
  }

  /// A settled one waits on nobody; an approval it merged with is still news.
  private static func reviewStatus(of pullRequest: PullRequest) -> CIRunStatus? {
    switch pullRequest.review {
    case .approved: .passed
    case .changesRequested: pullRequest.state.isSettled ? nil : .failed
    case .required: pullRequest.state.isSettled ? nil : .onHold
    case .notRequired: nil
    }
  }

  private static func wait(readiness: MergeReadiness, steps: [Step]) -> Wait {
    // Machines alone holding it back would offer Merge When Ready, so the only
    // machine wait left here is Multishell's read of the checks.
    readiness.awaitsChecksRead ? .checksRead : .steps(steps.count { $0.status != .passed })
  }
}
