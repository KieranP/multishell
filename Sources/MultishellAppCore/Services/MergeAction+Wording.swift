import MultishellCore

extension MergeAction {
  public var title: String {
    switch self {
    case .merge: t("action.merge")
    case .mergeWhenReady: t("action.merge-when-ready")
    case .cancelAutoMerge: t("action.cancel-auto-merge")
    }
  }
}
