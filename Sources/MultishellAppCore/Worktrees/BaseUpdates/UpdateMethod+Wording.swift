import MultishellCore

extension UpdateMethod {
  /// The stop's menu item, "Abort Merge" or "Abort Rebase".
  public var abortLabel: String {
    switch self {
    case .merge: t("base-update.abort-merge")
    case .rebase: t("base-update.abort-rebase")
    }
  }

  /// The confirming button's word, "Merge" or "Rebase".
  var actionLabel: String {
    switch self {
    case .merge: t("base-update.merge")
    case .rebase: t("base-update.rebase")
    }
  }

  /// "the merge" or "the rebase", inside a sentence.
  var noun: String {
    switch self {
    case .merge: t("base-update.the-merge")
    case .rebase: t("base-update.the-rebase")
    }
  }

  /// What a row says while one is stopped there: "Rebasing · 2 conflicts".
  func unfinishedText(conflicts: Int) -> String {
    let doing =
      switch self {
      case .merge: t("base-update.merging")
      case .rebase: t("base-update.rebasing")
      }
    guard conflicts > 0 else { return doing }
    return t("base-update.doing-with-conflicts", doing, t("base-update.conflicts", conflicts))
  }
}
