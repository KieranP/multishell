import MultishellCore
import MultishellServices

extension PullRequest {
  /// "#44 Fix the sidebar", as the row's tooltip heads it.
  var numberedTitle: String {
    t("pull-request.number-title", String(number), title)
  }
}
