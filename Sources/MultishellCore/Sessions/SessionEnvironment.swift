import Foundation

/// What every shell the app starts finds in its environment, so a hook or a
/// script inside it can name its tab when it reports a state.
public enum SessionEnvironment {
  public static let sessionKey = "MULTISHELL_SESSION"
  public static let worktreeKey = "MULTISHELL_WORKTREE"
  public static let socketKey = "MULTISHELL_SOCKET"
  /// The app's own pid, where the helper's walk up from a prompt stops; see
  /// Docs/design/agents.md.
  public static let appPIDKey = "MULTISHELL_APP_PID"

  /// `engineZshBootstrap` is the directory holding the terminal engine's own
  /// zsh startup file, when the engine has one it wants entered first.
  public static func variables(
    for session: TerminalSession, socket: URL, engineZshBootstrap: URL? = nil
  ) -> [String: String] {
    var variables = [
      sessionKey: session.id.uuidString,
      worktreeKey: session.workingDirectory.path,
      socketKey: socket.path,
      appPIDKey: String(ProcessInfo.processInfo.processIdentifier),
    ]
    variables.merge(
      ShellLaunch.zshIntegration(
        shellPath: session.shellPath, engineZshBootstrap: engineZshBootstrap)
    ) { current, _ in current }
    return variables
  }
}
