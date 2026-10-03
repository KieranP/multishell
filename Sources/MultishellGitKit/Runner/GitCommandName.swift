import MultishellCore

/// What a git run is grouped under: the subcommand and its flags, a flag's
/// value dropped, so two reads of different branches count as one command.
/// Global options before the subcommand are left out.
enum GitCommandName {
  /// Global options whose value is the next argument rather than after `=`.
  private static let globalOptionsTakingAValue: Set<String> = [
    "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
  ]

  /// Subcommands whose next word is the action they take, `worktree remove`.
  private static let subcommandsWithActions: Set<String> = [
    "worktree", "remote", "stash", "submodule", "notes", "sparse-checkout", "bisect",
  ]

  static func of(_ arguments: [String]) -> String {
    var rest = arguments[...]
    while let first = rest.first, first.hasPrefix("-") {
      rest = rest.dropFirst(globalOptionsTakingAValue.contains(first) ? 2 : 1)
    }
    guard let subcommand = rest.popFirst() else { return "" }
    var words = [subcommand]
    if subcommandsWithActions.contains(subcommand), let action = rest.first,
      !action.hasPrefix("-")
    {
      words.append(action)
      rest = rest.dropFirst()
    }
    let flags = rest.prefix { $0 != "--" }
      .filter { $0.hasPrefix("-") }
      .map { String($0.prefix { $0 != "=" }) }
      .uniqued(by: \.self)
    return (words + flags).joined(separator: " ")
  }
}
