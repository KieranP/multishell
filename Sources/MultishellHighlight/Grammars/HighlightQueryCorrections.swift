import MultishellAppCore

/// Patterns of ours read after a language's own queries: restatements of ones a later general
/// pattern overrides, and tokens a shipped query misses.
enum HighlightQueryCorrections {
  private static let customProperties = """
    ((property_name) @variable (#match? @variable "^--"))
    ((plain_value) @variable (#match? @variable "^--"))
    """

  private static let scssNames = """
    (mixin_statement name: (identifier) @function)
    (function_statement name: (identifier) @function)
    """

  // The grammar lexes `{:else if}` as one token, which the shipped `"else"` and `"if"` miss.
  private static let svelteElseIf = "\"else if\" @keyword"

  private static let queries: [HighlightLanguage: String] = [
    .css: customProperties, .scss: customProperties + "\n" + scssNames, .svelte: svelteElseIf,
  ]

  static func query(for language: HighlightLanguage) -> String? {
    queries[language]
  }
}
