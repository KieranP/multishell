import MultishellCore
import MultishellServices

/// What the merge form says around its fields.
extension PendingMerge {
  /// `nil` until a method is chosen, and once the host accepted it.
  public var confirmTitle: String? {
    guard let method, !wasAccepted else { return nil }
    if waitsForChecks { return t("merge-form.confirm-auto-merge") }
    return switch method {
    case .merge: t("merge-form.confirm-merge")
    case .rebase: t("merge-form.confirm-rebase")
    case .squash: t("merge-form.confirm-squash")
    }
  }

  /// Cancel, until the host accepted it.
  public var dismissTitle: String {
    wasAccepted ? t("merge-form.done") : t("merge-form.cancel")
  }

  public static func readingText(hostName: String) -> String {
    t("merge-form.reading", hostName)
  }

  public func heading(base: String) -> String {
    let number = String(pullRequestNumber)
    return waitsForChecks
      ? t("merge-form.heading-when-ready", number) : t("merge-form.heading", number, base)
  }

  /// Said only for auto-merge, which lands later, without the app, and with
  /// whatever is pushed before then.
  public func lede(hostName: String) -> String? {
    waitsForChecks ? t("merge-form.lede-when-ready", hostName) : nil
  }

  /// In place of the message fields, for a method that takes none.
  public func noMessageNote(base: String) -> String? {
    method?.takesMessage == false ? t("merge-form.rebase-note", base) : nil
  }

  /// Why Confirm is off whatever is written, or that the host accepted it: a
  /// merge queue accepts it without merging, so "took", not "merged".
  public func statusNote(hostName: String) -> String? {
    let number = String(pullRequestNumber)
    if wasAccepted {
      return waitsForChecks
        ? t("merge-form.accepted-when-ready", hostName, number)
        : t("merge-form.accepted", hostName, number)
    }
    return switch refusal {
    case .autoMergeOff: t("merge-form.auto-merge-off", hostName)
    case .viewerMayNotMerge: t("merge-form.viewer-may-not-merge", hostName)
    case nil: nil
    }
  }
}
