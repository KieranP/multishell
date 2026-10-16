/// A grammar's capture names put into roles, by first component but for the
/// exceptions, which vary by grammar: `constructor` is Swift's `init`.
public enum HighlightCaptureRoles {
  /// Marks for other tools, a spell checker's, that colour nothing.
  private static let notHighlights: Set<String> = ["spell"]

  /// Names whose first component would mislead: `variable.builtin` is `self`
  /// and `super`, `text.title` a Markdown heading, `character.special` Swift's `_`.
  private static let exceptions: [String: HighlightRole] = [
    "character.special": .plain, "variable.builtin": .keyword, "text.title": .keyword,
    "text.uri": .string,
    "text.literal": .string, "text.reference": .function, "string.special.key": .plain,
  ]

  /// Kotlin's, SQL's and Make's queries still use the older names:
  /// `conditional`, `repeat` and the like for a keyword, `float` for a number.
  private static let byFirstComponent: [String: HighlightRole] = [
    "attribute": .attribute, "boolean": .number, "character": .string, "comment": .comment,
    "conditional": .keyword, "constant": .number, "delimiter": .punctuation,
    "escape": .string, "exception": .keyword, "float": .number, "function": .function,
    "import": .keyword, "include": .keyword, "keyword": .keyword, "module": .type,
    "namespace": .type, "number": .number, "punctuation": .punctuation, "repeat": .keyword,
    "storageclass": .keyword, "string": .string, "tag": .keyword, "type": .type,
  ]

  /// Swift marks `init` as a constructor where the others mark a class name.
  private static func constructorRole(in language: HighlightLanguage) -> HighlightRole {
    language == .swift ? .keyword : .type
  }

  /// `.plain` for `variable`, `operator`, `label` and the like, which still
  /// override an earlier pattern; `nil` for a mark that is no highlight.
  public static func role(
    forCapture name: String,
    in language: HighlightLanguage,
  ) -> HighlightRole? {
    guard !notHighlights.contains(name) else { return nil }
    if name == "constructor" { return constructorRole(in: language) }
    if let exception = exceptions[name] { return exception }
    let first = name.split(separator: ".").first.map(String.init) ?? name
    return byFirstComponent[first] ?? .plain
  }
}
