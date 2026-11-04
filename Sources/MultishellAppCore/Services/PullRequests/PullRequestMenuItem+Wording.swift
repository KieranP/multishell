import MultishellCore

extension PullRequestMenuItem {
  public var title: String {
    switch self {
    case .create: t("action.create-pull-request")
    case .open(let number): t("action.open-pull-request", String(number))
    }
  }
}
