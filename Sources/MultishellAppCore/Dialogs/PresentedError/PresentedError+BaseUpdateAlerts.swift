import MultishellCore
import MultishellGitKit

extension PresentedError {
  /// Why Merge from Base, Rebase onto Base or its Abort did not start.
  static func baseUpdateAlert(_ error: any Error) -> Alert? {
    switch error {
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
