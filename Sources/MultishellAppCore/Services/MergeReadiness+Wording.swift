import MultishellCore
import MultishellServices

/// What the SCM panel says of whether a pull request can merge.
extension MergeReadiness {
  private static func text(of blocker: Blocker, base: String) -> String {
    switch blocker {
    case .behindBase: t("pull-request.behind-base", base)
    case .blockedByRules: t("pull-request.blocked-by-rules", base)
    case .changesRequested: t("pull-request.changes-requested")
    case .checksNotRead: t("readiness.checks-not-read")
    case .conflicts: t("pull-request.conflicts", base)
    case .conflictsUnchecked: t("readiness.checking-conflicts", base)
    case .draft: t("readiness.draft")
    case .failingChecks(let count): t("count.required-checks-failed", count)
    case .pendingChecks(let count): t("count.required-checks-running", count)
    case .reviewRequired: t("readiness.waiting-on-review")
    }
  }

  public func title(base: String) -> String {
    switch verdict {
    case .closed: t("pull-request.closed")
    case .merged: t("pull-request.merged", base)
    case .notReady: t("readiness.not-ready")
    case .ready, .readyWithOptionalFailures: t("readiness.ready")
    }
  }

  /// Why it is or is not ready; `nil` once it is merged or closed.
  public func detail(base: String) -> String? {
    switch verdict {
    case .closed, .merged: nil
    case .notReady: blockers.map { Self.text(of: $0, base: base) }.joined(separator: " · ")
    case .ready: t("readiness.every-required-check-passed")
    case .readyWithOptionalFailures: t("readiness.optional-check-failed")
    }
  }
}
