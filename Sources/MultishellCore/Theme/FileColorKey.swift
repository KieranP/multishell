/// A colour a theme's `file` section sets, written in the file as its raw
/// value: one per highlight role, and the rest of a file tab's rows.
public enum FileColorKey: String, CaseIterable, Sendable {
  case added
  case addedBackground = "added_background"
  case addedWordBackground = "added_word_background"
  case attribute
  case background
  case comment
  case divider
  case findMatch = "find_match"
  case function
  case keyword
  case lineNumber = "line_number"
  case number
  case paddingBackground = "padding_background"
  case punctuation
  case removed
  case removedBackground = "removed_background"
  case removedText = "removed_text"
  case removedWordBackground = "removed_word_background"
  case selectionBackground = "selection_background"
  case string
  case text
  case type
}
