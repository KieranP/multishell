/// What the quit confirmation says while terminals are open. Every open
/// session is a live pty, and quitting kills whatever is running in it.
public enum QuitGuard {
  /// Working agents are counted apart from plain shells: a shell at a prompt
  /// loses nothing, an agent mid-task loses the task.
  public static func message(terminals: Int, working: Int) -> String {
    let shells =
      terminals == 1
      ? "One terminal is still open and will be closed."
      : "\(terminals) terminals are still open and will be closed."
    switch working {
    case 0: return shells
    case 1: return shells + " One of them has an agent that is still working."
    default: return shells + " \(working) of them have agents that are still working."
    }
  }
}
