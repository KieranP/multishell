import MultishellCore
import MultishellServices

/// The status a CI glyph draws, which the name beside it does not say.
extension AccessibilityText {
  public static func ciStatus(_ status: CIRunStatus) -> String {
    switch status {
    case .cancelled: t("spoken.ci-cancelled")
    case .failed: t("spoken.ci-failed")
    case .onHold: t("spoken.ci-on-hold")
    case .passed: t("spoken.ci-passed")
    case .running: t("spoken.ci-running")
    case .unknown: t("spoken.ci-unknown")
    }
  }

  /// An earlier run's row, which opens onto its workflows.
  public static func ciStatus(_ status: CIRunStatus, isExpanded: Bool) -> String {
    [ciStatus(status), disclosure(isExpanded: isExpanded)].joined(separator: ", ")
  }
}
