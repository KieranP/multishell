import MultishellCore

/// A setting a project does not override: the value in force and its source,
/// for the Global column and the captions under it; Docs/design/settings.md.
public struct InheritedSetting<Value: Equatable & Sendable>: Equatable, Sendable {
  public let value: Value
  /// The repository's file supplies it, rather than the user's global.
  let isFromRepository: Bool

  /// The Global column's cell, `shown` being the value as the row writes it
  /// and `section` the All Projects page that sets the global.
  func globalValue(
    _ shown: String,
    setIn section: SettingsSection?,
    blankWord: String = t("inherited.none"),
  ) -> OverrideGlobalValue {
    OverrideGlobalValue(
      text: shown,
      blankWord: blankWord,
      source: isFromRepository ? .repository : .global,
      settingsSection: section,
    )
  }
}

extension InheritedSetting where Value == Bool {
  public func globalValue(setIn section: SettingsSection?) -> OverrideGlobalValue {
    globalValue(value ? t("inherited.on") : t("inherited.off"), setIn: section)
  }
}

extension InheritedSetting where Value == WorktreeSortOrder {
  /// The label the picker gives it, so the column and the row agree. Set from
  /// the sidebar's own menu, so no page opens from it.
  public var globalValue: OverrideGlobalValue { globalValue(value.displayName, setIn: nil) }
}

extension InheritedSetting where Value == String {
  /// A branch prefix, blank being none.
  public var prefixGlobalValue: OverrideGlobalValue { globalValue(value, setIn: .worktrees) }

  /// A worktree directory, blank being the default one.
  public var directoryGlobalValue: OverrideGlobalValue {
    globalValue(value, setIn: .worktrees, blankWord: t("inherited.default"))
  }
}
