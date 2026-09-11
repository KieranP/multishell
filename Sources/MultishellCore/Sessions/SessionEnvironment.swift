import Foundation

/// What every shell the app starts finds in its environment, so a hook or a
/// script inside it can name its tab when it reports a state.
public enum SessionEnvironment {
  public static let sessionKey = "MULTISHELL_SESSION"
  public static let worktreeKey = "MULTISHELL_WORKTREE"
  public static let socketKey = "MULTISHELL_SOCKET"

  /// The variable Ghostty's zsh bootstrap reads to find the `ZDOTDIR` it
  /// displaced, and hands `ZDOTDIR` back to before the first startup file.
  public static let ghosttyZdotdirKey = "GHOSTTY_ZSH_ZDOTDIR"

  /// `engineZshBootstrap` is the directory holding the terminal engine's own
  /// zsh startup file, when the engine has one it wants entered first.
  public static func variables(
    for session: TerminalSession, socket: URL, engineZshBootstrap: URL? = nil
  ) -> [String: String] {
    var variables = [
      sessionKey: session.id.uuidString,
      worktreeKey: session.workingDirectory.path,
      socketKey: socket.path,
    ]
    variables.merge(
      zshIntegration(shellPath: session.shellPath, engineBootstrap: engineZshBootstrap)
    ) { current, _ in current }
    return variables
  }

  /// Points a zsh session's `ZDOTDIR` at the generated directory. Under
  /// Ghostty it sets the pair the engine would have; see terminals.md.
  static func zshIntegration(
    shellPath: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    integrationDirectory: URL = Paths.zshIntegrationDirectory,
    engineBootstrap: URL? = nil
  ) -> [String: String] {
    let shell = URL(fileURLWithPath: shellPath).lastPathComponent
    guard shell == "zsh",
      FileManager.default.fileExists(atPath: integrationDirectory.path)
    else { return [:] }
    var variables = ["ZDOTDIR": integrationDirectory.path]
    if let bootstrap = engineBootstrap,
      FileManager.default.fileExists(atPath: bootstrap.appendingPathComponent(".zshenv").path)
    {
      variables["ZDOTDIR"] = bootstrap.path
      variables[ghosttyZdotdirKey] = integrationDirectory.path
    }
    if let user = environment["ZDOTDIR"], !user.isEmpty {
      variables["MULTISHELL_USER_ZDOTDIR"] = user
    }
    return variables
  }
}
