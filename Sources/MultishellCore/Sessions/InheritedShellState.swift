/// What a shell's tools keep about its own session, inherited from the terminal
/// that started the app; handed on, mise rebuilt a pane's PATH; terminals.md.
public enum InheritedShellState {
  private static let misePrefix = "__MISE_"
  /// What direnv loaded, not its settings such as its log format.
  private static let direnvRecord: Set<String> = [
    "DIRENV_DIR", "DIRENV_FILE", "DIRENV_DIFF", "DIRENV_WATCHES",
  ]

  public static func names(in environment: [String: String]) -> [String] {
    environment.keys.filter { key in
      direnvRecord.contains(key) || key.hasPrefix(misePrefix)
    }
    .sorted()
  }
}
