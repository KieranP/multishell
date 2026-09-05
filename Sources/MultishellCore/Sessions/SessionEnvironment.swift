import Foundation

/// What every shell the app starts finds in its environment, so a hook or a
/// script inside it can name its tab when it reports a state.
public enum SessionEnvironment {
  public static let sessionKey = "MULTISHELL_SESSION"
  public static let worktreeKey = "MULTISHELL_WORKTREE"
  public static let socketKey = "MULTISHELL_SOCKET"

  public static func variables(for session: TerminalSession, socket: URL) -> [String: String] {
    var variables = [
      sessionKey: session.id.uuidString,
      worktreeKey: session.workingDirectory.path,
      socketKey: socket.path,
    ]
    variables.merge(zshIntegration(shellPath: session.shellPath)) { current, _ in current }
    return variables
  }

  /// When the app has generated the zsh integration directory and the tab's
  /// shell is zsh, point the session at it and pass the user's own `ZDOTDIR`
  /// along so the generated files can chain to it. Absent otherwise, so a
  /// disabled setting or a non-zsh shell adds nothing.
  static func zshIntegration(
    shellPath: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    integrationDirectory: URL = Paths.zshIntegrationDirectory
  ) -> [String: String] {
    let shell = URL(fileURLWithPath: shellPath).lastPathComponent
    guard shell == "zsh",
      FileManager.default.fileExists(atPath: integrationDirectory.path)
    else { return [:] }
    var variables = ["ZDOTDIR": integrationDirectory.path]
    if let user = environment["ZDOTDIR"], !user.isEmpty {
      variables["MULTISHELL_USER_ZDOTDIR"] = user
    }
    return variables
  }
}
