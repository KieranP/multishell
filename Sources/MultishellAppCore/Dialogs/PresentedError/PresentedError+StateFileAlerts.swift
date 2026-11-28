import Foundation
import MultishellCore

extension PresentedError {
  /// The app's state file, unread at launch or unsaved since.
  static func stateFileAlert(_ error: any Error) -> Alert? {
    switch error {
    case let state as UnreadableStateFile:
      return (
        t("error.unreadable-state-title"),
        t(
          "error.unreadable-state-message",
          state.backup.lastPathComponent,
          String(describing: state.underlying),
        ),
      )

    case let link as DanglingStateFileLink:
      return (
        t("error.unreadable-state-title"),
        t("error.dangling-state-link-message", link.fileURL.path, link.target.path),
      )

    case let state as UnmovableStateFile:
      return (
        t("error.unreadable-state-title"),
        t("error.unmoved-state-message", state.fileURL.path, String(describing: state.underlying)),
      )

    case let link as GoneStateFileLinkTarget:
      return (
        t("error.state-not-saved-title"),
        t("error.gone-state-link-message", link.fileURL.path, link.target.path),
      )

    default:
      return nil
    }
  }
}
