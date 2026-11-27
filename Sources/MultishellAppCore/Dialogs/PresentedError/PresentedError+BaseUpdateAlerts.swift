import MultishellCore
import MultishellGitKit

extension PresentedError {
  /// Why Merge from Base or Rebase onto Base did not start.
  static func baseUpdateAlert(_ error: any Error) -> Alert? {
    switch error {
    case let refused as UncommittedChangesRefusal:
      let reason =
        switch refused.method {
        case .merge: t("base-update.uncommitted-merge-message", refused.base.shortName)
        case .rebase: t("base-update.uncommitted-rebase-message", refused.base.shortName)
        }
      let listed = UncommittedChangeList(refused.changes)
      var lines = listed.shown
      if listed.unlisted > 0 { lines.append(t("base-update.uncommitted-more", listed.unlisted)) }
      return (
        t("base-update.uncommitted-title", refused.branch),
        reason + "\n\n" + lines.joined(separator: "\n"),
      )

    case let missing as BaseRemoteMissing:
      return (
        t("base-update.remote-missing-title", missing.base), t("base-update.remote-missing"),
      )

    case let locked as IndexLocked:
      return (t("base-update.index-locked-title"), t("base-update.index-locked", locked.message))

    default:
      return nil
    }
  }
}
