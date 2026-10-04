import Foundation

/// What every shell the app starts finds in its environment, so a hook or a
/// script inside it can name its tab when it reports a state.
public enum SessionEnvironment {
  public static let sessionVariable = "MULTISHELL_SESSION"
  public static let worktreeVariable = "MULTISHELL_WORKTREE"
  public static let socketVariable = "MULTISHELL_SOCKET"
  /// The app's own pid, where the helper's walk up from a prompt stops; see
  /// Docs/design/agents.md.
  public static let appPIDVariable = "MULTISHELL_APP_PID"

  public static func variables(for session: TerminalSession, socket: URL) -> [String: String] {
    var variables = [
      sessionVariable: session.id.uuidString,
      worktreeVariable: session.workingDirectory.path,
      socketVariable: socket.path,
      appPIDVariable: String(ProcessInfo.processInfo.processIdentifier),
    ]
    variables.merge(ShellLaunch.zshEnvironment(forShell: session.shellPath)) { current, _ in
      current
    }
    return variables
  }
}
