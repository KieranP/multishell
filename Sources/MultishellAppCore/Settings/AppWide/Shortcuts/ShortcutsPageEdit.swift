/// What the Shortcuts page is part way through, one thing at a time: a row's
/// change, or Restore Defaults asking.
enum ShortcutsPageEdit: Hashable, Sendable {
  case restoringDefaults
  case row(ShortcutEditing)
}
