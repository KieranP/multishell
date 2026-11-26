extension ProjectAction {
  /// The command as written, with the worktree's values in their variables,
  /// `MULTISHELL_PORT` and the rest; see Docs/design/actions.md. Always sh.
  public func scriptLine(values: [WorktreePlaceholder: String]) -> ShellLine {
    let environment = Dictionary(uniqueKeysWithValues: values.map { ($0.key.variable, $0.value) })
    return ShellLine(text: command, environment: environment)
  }
}
