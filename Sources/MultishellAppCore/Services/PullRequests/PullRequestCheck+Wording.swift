import MultishellCore
import MultishellServices

extension PullRequestCheck {
  /// "CI / build", or the name alone where the host groups it in no workflow.
  public var displayName: String {
    workflow.map { t("readiness.check-in-workflow", $0, name) } ?? name
  }
}
