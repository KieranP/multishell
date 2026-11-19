/// Why keys cannot be a command's, said under the row while it records.
public enum ShortcutRefusal: Hashable, Sendable {
  /// ⌘ with an arrow or Delete, or ⌃⇧ with a sideways arrow, moves, selects or
  /// deletes to a line's or a text's ends in every text field.
  case editsText
  /// A fixed command, Copy or Undo say, holds the keys and cannot let them go.
  case heldByFixed(ShortcutCommand)
  /// No ⌘, ⌃ or ⌥, and not an F-key: every text field would lose the key.
  case needsModifier
  /// ⌥ with a key `KeyCombination+Refusal` lists moves or deletes by word, or
  /// breaks a line, in every text field.
  case optionEditsText
  /// ⌥ and a character types a character on many layouts, ⌥L being @ on a
  /// German one, in every text field.
  case optionTypesCharacter
  /// A key a pane's program needs, or one the pane types before the menus see it.
  case programKey(KeyCombination)
  case reserved(ReservedShortcut)
}
