/// Edits to a shipped query whose predicates SwiftTreeSitter does not evaluate: it
/// lets every match of an unknown predicate through.
enum ShippedQueryRewrites {
  /// Zig's Lua patterns use no `%` class, so each reads the same as a regular expression.
  static func rewritten(_ query: String) -> String {
    query.replacing("#not-lua-match?", with: "#not-match?")
      .replacing("#lua-match?", with: "#match?")
  }
}
