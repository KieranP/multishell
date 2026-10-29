import MultishellCore
import MultishellServices

extension PullRequestMergeMethod {
  /// A segment of the merge form's method switch.
  public var name: String {
    switch self {
    case .merge: t("merge-method.merge")
    case .squash: t("merge-method.squash")
    case .rebase: t("merge-method.rebase")
    }
  }
}
