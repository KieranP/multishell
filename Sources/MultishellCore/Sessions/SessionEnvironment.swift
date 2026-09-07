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

  /// When the app has generated the zsh integration directory and the tab's
  /// shell is zsh, point the session at it and pass the user's own `ZDOTDIR`
  /// along so the generated files can chain to it. Absent otherwise, so a
  /// disabled setting or a non-zsh shell adds nothing.
  ///
  /// libghostty applies a surface's variables after it has set up its own
  /// shell integration, so a `ZDOTDIR` given here replaces the one it set and
  /// its integration never loads. When the engine has a bootstrap, this sets
  /// the pair it would have: `ZDOTDIR` at the bootstrap, and ours where the
  /// bootstrap looks for the directory it displaced.
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
