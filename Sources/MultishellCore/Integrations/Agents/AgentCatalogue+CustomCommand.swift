extension AgentCatalogue {
  /// The custom agent command, which runs as written: each placeholder reads
  /// a variable, so no value is ever shell text. See Docs/design/agents.md.
  public static func customCommandLine(
    _ line: String, values: [WorktreePlaceholder: String]
  ) -> ShellLine {
    var tokens: [String: (variable: String, value: String)] = [:]
    for (placeholder, value) in values {
      tokens[placeholder.token] = (placeholder.variable, value)
    }
    return ShellLine(line, substituting: tokens)
  }
}
