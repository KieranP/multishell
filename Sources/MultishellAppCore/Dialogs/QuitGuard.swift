import MultishellCore

/// What the quit confirmation says while terminals are open. Every open
/// session is a live pty, and quitting kills whatever is running in it.
public enum QuitGuard {
  /// Working agents are counted apart from plain shells: a shell at a prompt
  /// loses nothing, an agent mid-task loses the task.
  public static func message(terminals: Int, working: Int) -> String {
    let shells = t("quit.terminals-open", terminals)
    guard working > 0 else { return shells }
    return shells + " " + t("quit.agents-working", working)
  }
}
