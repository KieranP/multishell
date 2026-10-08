extension String {
  /// The format specifiers in a catalogue's English text, numbered ones
  /// counted once per number.
  public var formatPlaceholders: [String] {
    let all = matches(of: /%[0-9]*\$?[0-9.]*[@dfs]/).map { String($0.output) }
    let numbered = Set(all.filter { $0.contains("$") }.map { $0.prefix { $0 != "$" } })
    return numbered.isEmpty ? all : Array(repeating: "%1$@", count: numbered.count)
  }
}
