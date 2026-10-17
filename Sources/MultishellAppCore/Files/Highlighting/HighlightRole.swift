/// What a highlighted range is, which the theme's `file` section colours.
public enum HighlightRole: Hashable, Sendable {
  case attribute
  case comment
  case function
  case keyword
  /// A number, a boolean or a built-in constant.
  case number
  case plain
  case punctuation
  case string
  case type
}
