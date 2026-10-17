/// What a highlighted range is, which a theme slot colours: a user theme then
/// recolours highlighting with nothing new to write.
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
