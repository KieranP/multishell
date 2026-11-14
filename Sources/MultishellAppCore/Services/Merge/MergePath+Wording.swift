import MultishellCore
import MultishellServices

/// What the pull request page says of each step, of where the path ends and
/// under the card.
extension MergePath {
  /// A failed read after one that answered is said under the card; one with
  /// none answered is the checks step's own.
  public var staleChecksNote: String? {
    guard let checks, let checksReadProblem else { return nil }
    return checks.isEmpty
      ? t("merge-path.not-read-again", checksReadProblem)
      : t("merge-path.stale-checks", checksReadProblem)
  }

  private var checksNotReadTitle: String {
    checksReadProblem == nil ? t("merge-path.reading") : t("merge-path.not-read")
  }

  private var checksReadWait: String {
    checksReadProblem == nil ? t("merge-path.waits-on-reading") : t("merge-path.waits-on-read")
  }

  private static func conflictsTitle(_ status: CIRunStatus, base: String) -> String {
    switch status {
    case .failed: t("pull-request.conflicts", base)
    case .running, .unknown: t("readiness.checking-conflicts", base)
    case .cancelled, .onHold, .passed: t("readiness.no-conflicts", base)
    }
  }

  private static func reviewTitle(_ status: CIRunStatus) -> String {
    switch status {
    case .failed: t("pull-request.changes-requested")
    case .passed: t("readiness.review-approved")
    case .cancelled, .onHold, .running, .unknown: t("readiness.waiting-on-review")
    }
  }

  /// "2 of 4 required passed, 1 failing, 1 not run. 1 optional failed": a skipped
  /// or cancelled check, which the verdict lets pass, is named apart.
  private static func summary(of checks: [PullRequestCheck]) -> String {
    let required = checks.filter(\.isRequired)
    let passed = required.count { $0.status == .passed }
    let failing = required.count { $0.status == .failed }
    let running = required.count(where: \.status.isUnderWay)
    let notRun = required.count { [.cancelled, .onHold, .unknown].contains($0.status) }
    let optionalFailed = checks.count { !$0.isRequired && $0.status == .failed }
    let requiredPassed =
      required.isEmpty
      ? t("merge-path.none-required")
      : t("merge-path.of-required", passed, t("count.merge-path-required-passed", required.count))
    var parts = [requiredPassed]
    if failing > 0 { parts.append(t("count.merge-path-failing", failing)) }
    if running > 0 { parts.append(t("count.merge-path-running", running)) }
    if notRun > 0 { parts.append(t("count.merge-path-not-run", notRun)) }
    let summary = parts.joined(separator: ", ")
    guard optionalFailed > 0 else { return summary }
    let optional = t("count.merge-path-optional-failed", optionalFailed)
    return t("merge-path.with-optional-failed", summary, optional)
  }

  public func title(of step: Step, base: String) -> String {
    switch step.kind {
    case .behindBase: t("pull-request.behind-base", base)
    case .blockedByRules: t("merge-path.rule", base)
    case .checks: t("merge-path.checks")
    case .checksNotRead: checksNotReadTitle
    case .conflicts: Self.conflictsTitle(step.status, base: base)
    case .draft: t("readiness.draft")
    case .review: Self.reviewTitle(step.status)
    }
  }

  /// What fixes a step that needs the user, what a person's wait is, or the
  /// checks' count.
  public func hint(of step: Step, base: String, host: String) -> String? {
    switch step.kind {
    case .behindBase: t("merge-path.merge-base", base)
    case .blockedByRules: t("merge-path.rule-hint", host)
    case .checks: checks.map(Self.summary(of:))
    case .checksNotRead: checksReadProblem.map { t("merge-path.read-again", $0) }
    case .conflicts: step.status == .failed ? t("merge-path.merge-base", base) : nil
    case .draft: t("merge-path.draft-hint", host)
    case .review: step.status == .onHold ? t("merge-path.review-hint") : nil
    }
  }

  public func endTitle(base: String) -> String {
    switch end {
    case .closed: t("pull-request.closed")
    case .merged: t("pull-request.merged", base)
    case .offers(.merge), .taken, .waits: t("merge-path.merge-into", base)
    case .offers(.mergeWhenReady): t("merge-path.merge-when-ready")
    case .offers(.cancelAutoMerge): t("merge-path.auto-merges", base)
    }
  }

  public func endHint(host: String) -> String? {
    switch end {
    case .closed: t("merge-path.closed-hint", host)
    case .merged(let isOutgrown): isOutgrown ? t("merge-path.outgrown-hint") : nil
    case .offers(.merge): nil
    case .taken: t("merge-path.taken-hint", host)
    case .offers(.mergeWhenReady): t("merge-path.merge-when-ready-hint")
    case .offers(.cancelAutoMerge): t("merge-path.auto-merges-hint")
    case .waits(.checksRead): checksReadWait
    case .waits(.steps(let count)): t("count.merge-path-steps-left", count)
    }
  }
}
