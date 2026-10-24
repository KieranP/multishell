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
  /// Ours, for a shell's integration to put back in front once a login
  /// profile's `path_helper` has moved `/etc/paths` ahead; terminals.md.
  static let leadingPathVariable = "MULTISHELL_LEADING_PATH"

  /// `bundle` names the helper's and the app's directories, where PATH is
  /// written whole: the engine reads an embedder's after its own append.
  public static func variables(
    for session: TerminalSession,
    socket: URL,
    bundle: BundleDirectories? = nil,
    inheritedPath: String? = ProcessInfo.processInfo.environment["PATH"],
  ) -> [String: String] {
    var variables = [
      sessionVariable: session.id.uuidString,
      worktreeVariable: session.workingDirectory.path,
      socketVariable: socket.path,
      appPIDVariable: String(ProcessInfo.processInfo.processIdentifier),
    ]
    if let port = session.port { variables[WorktreePlaceholder.port.variable] = String(port) }
    if let bundle {
      variables["PATH"] = searchPath(inheritedPath, leadingWith: bundle)
      variables[leadingPathVariable] = leadingEntries(of: bundle).joined(separator: ":")
    }
    variables.merge(ShellLaunch.zshEnvironment(forShell: session.shellPath)) { current, _ in
      current
    }
    return variables
  }
}
