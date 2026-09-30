import MultishellCore

extension PresentedError {
  /// An agent's settings file, or the app's own state file, that would not read.
  static func settingsOrStateFileAlert(_ error: any Error) -> Alert? {
    switch error {
    case let entries as UnreadableHookEntries:
      return (
        t("error.unknown-hooks-title"),
        t("error.unknown-hooks-message", entries.file.path, entries.event)
      )
    case let section as UnreadableHookSection:
      return (
        t("error.unknown-hooks-title"),
        t("error.unknown-hooks-section-message", section.file.path)
      )
    case let unparsable as UnparsableSettingsFile:
      return (
        t("error.unparsable-settings-title"),
        t("error.unparsable-settings-message", unparsable.file.path)
      )
    case let shape as UnexpectedSettingsShape:
      return (t("error.settings-shape-title"), t("error.settings-shape-message", shape.file.path))
    case let state as UnreadableStateFile:
      return (
        t("error.unreadable-state-title"),
        t(
          "error.unreadable-state-message",
          state.backup.lastPathComponent, String(describing: state.underlying))
      )
    case let state as UnmovableStateFile:
      return (
        t("error.unreadable-state-title"),
        t("error.unmoved-state-message", state.file.path, String(describing: state.underlying))
      )
    default:
      return nil
    }
  }
}
