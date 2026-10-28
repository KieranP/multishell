import MultishellCore
import MultishellServices

extension MergeReadiness.Requirement {
  /// "Review approved", "No conflicts with main", or the check's workflow and name.
  public func name(base: String) -> String {
    switch kind {
    case .check(let check):
      return check.workflow.map { t("readiness.check-in-workflow", $0, check.name) } ?? check.name

    case .conflicts:
      switch status {
      case .failed: return t("pull-request.conflicts", base)
      case .running: return t("readiness.checking-conflicts", base)
      case .cancelled, .onHold, .passed: return t("readiness.no-conflicts", base)
      }

    case .review:
      switch status {
      case .failed: return t("pull-request.changes-requested")
      case .passed: return t("readiness.review-approved")
      case .cancelled, .onHold, .running: return t("pull-request.review-required")
      }
    }
  }
}
