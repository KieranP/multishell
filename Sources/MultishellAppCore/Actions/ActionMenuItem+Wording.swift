import Foundation
import MultishellCore

extension ActionMenuItem {
  /// The line under a play menu row's name, as `running 12m`; `nil` while idle.
  /// Its keys sit at the row's right, as a menu bar item's do.
  public func stateWords(now: Date) -> String? {
    switch state {
    case .idle: nil
    case .done: t("project-action.done")
    case .failed: t("project-action.failed")

    case .running(let since):
      ElapsedText.short(since: since, now: now).map { t("project-action.running-for", $0) }
        ?? t("project-action.running")
    }
  }
}
