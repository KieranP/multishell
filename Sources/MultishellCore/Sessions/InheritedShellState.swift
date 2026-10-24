/// What a shell's tools, or a Multishell pane, keep about its session, inherited from
/// the terminal that started the app; handed on, mise rebuilt PATH. terminals.md.
public enum InheritedShellState {
  private static let misePrefix = "__MISE_"
  /// What direnv loaded, not its settings such as its log format.
  private static let direnvRecord: Set<String> = [
    "DIRENV_DIR", "DIRENV_FILE", "DIRENV_DIFF", "DIRENV_WATCHES",
  ]

  /// What `SessionEnvironment` and a custom agent command gave the launching
  /// pane. Kept, hooks reported to that pane and named another app's worktree.
  private static let paneRecord = Set(
    [
      SessionEnvironment.sessionVariable, SessionEnvironment.worktreeVariable,
      SessionEnvironment.socketVariable, SessionEnvironment.appPIDVariable,
      SessionEnvironment.leadingPathVariable, AgentCatalogue.taskVariable,
    ] + WorktreePlaceholder.allCases.map(\.variable)
  )

  public static func names(in environment: [String: String]) -> [String] {
    environment.keys.filter { key in
      direnvRecord.contains(key) || paneRecord.contains(key) || key.hasPrefix(misePrefix)
    }
    .sorted()
  }
}
