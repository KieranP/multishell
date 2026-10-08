import Foundation
import MultishellCore

extension Worker {
  public var displayName: String {
    name ?? type ?? (isBackgroundShell ? t("worker.background-shell") : t("worker.unnamed"))
  }

  /// How many workers this place stands for, where that is more than one.
  /// `nil` is drawn as nothing rather than as a 1 beside every name.
  public var occurrenceText: String? {
    occurrences > 1 ? t("worker.occurrences", occurrences) : nil
  }

  public func elapsed(at now: Date) -> String? {
    ElapsedText.short(since: startedAt, now: now)
  }
}
