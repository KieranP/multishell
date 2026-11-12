import Foundation
import MultishellCore

extension PresentedError {
  /// An agent's settings file, or the app's own state or review file, that would not read.
  static func settingsOrStateFileAlert(_ error: any Error) -> Alert? {
    switch error {
    case let entries as UnexpectedHookEntriesShape:
      return (
        t("error.unknown-hooks-title"),
        t("error.unknown-hooks-message", entries.file.path, entries.section, entries.event),
      )

    case let section as UnexpectedHookSectionShape:
      return (
        t("error.unknown-hooks-title"),
        t("error.unknown-hooks-section-message", section.file.path, section.section),
      )

    case let unparsable as UnparsableSettingsFile:
      return (
        t("error.unparsable-settings-title"),
        t("error.unparsable-settings-message", unparsable.file.path),
      )

    case let shape as UnexpectedSettingsShape:
      return (t("error.settings-shape-title"), t("error.settings-shape-message", shape.file.path))

    case let state as UnreadableStateFile:
      return (
        t("error.unreadable-state-title"),
        t(
          "error.unreadable-state-message",
          state.backup.lastPathComponent,
          String(describing: state.underlying),
        ),
      )

    case let review as UnreadableReviewFile:
      return (t("error.unreadable-review-title"), reviewFileMessage(review))

    case let reviews as UnreadableReviewFiles:
      return (
        t("error.unreadable-review-title"),
        reviews.files.map(reviewFileMessage).joined(separator: "\n\n"),
      )

    case let state as UnmovableStateFile:
      return (
        t("error.unreadable-state-title"),
        t("error.unmoved-state-message", state.fileURL.path, String(describing: state.underlying)),
      )

    default:
      return nil
    }
  }

  /// Where it went, or that it stayed, and what the read said.
  private static func reviewFileMessage(_ review: UnreadableReviewFile) -> String {
    let underlying = String(describing: review.underlying)
    guard let backup = review.backup else {
      return t("error.unmoved-review-message", review.fileURL.path, underlying)
    }
    return t("error.unreadable-review-message", backup.lastPathComponent, underlying)
  }
}
