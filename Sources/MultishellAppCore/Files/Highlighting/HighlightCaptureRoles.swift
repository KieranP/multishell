/// A grammar's capture names put into roles, by first component but for the
/// exceptions, some of which vary by grammar: `constructor` is Swift's `init`.
public enum HighlightCaptureRoles {
  /// Marks for other tools, a spell checker's, that colour nothing.
  private static let notHighlights: Set<String> = ["spell"]

  /// Names whose first component misleads: `variable.builtin` is `self`, `text.title` a
  /// heading, `character.special` Swift's `_`, `type.qualifier` Svelte's `{@const}` and SQL's `LOCAL`.
  private static let exceptions: [String: HighlightRole] = [
    "character.special": .plain, "variable.builtin": .keyword, "text.title": .keyword,
    "type.qualifier": .keyword,
    "text.uri": .string, "constructor": .type,
    "text.literal": .string, "text.reference": .function, "string.special.key": .plain,
  ]

  /// Read first: Swift's `constructor` is `init`, HTML's and Svelte's `constant` the doctype,
  /// and CSS's `property` a property or selector name where elsewhere it is a field.
  private static let exceptionsByLanguage: [HighlightLanguage: [String: HighlightRole]] = [
    .swift: ["constructor": .keyword],
    .html: ["constant": .keyword], .svelte: ["constant": .keyword],
    .css: ["property": .attribute], .scss: ["property": .attribute],
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

  /// `.plain` for `variable`, `operator`, `label` and the like, which still
  /// override an earlier pattern; `nil` for a mark that is no highlight.
  public static func role(
    forCapture name: String,
    in language: HighlightLanguage,
  ) -> HighlightRole? {
    guard !notHighlights.contains(name) else { return nil }
    if let exception = exceptionsByLanguage[language]?[name] ?? exceptions[name] {
      return exception
    }
    let first = name.split(separator: ".").first.map(String.init) ?? name
    return byFirstComponent[first] ?? .plain
  }
}
