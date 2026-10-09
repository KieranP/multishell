import Foundation
import MultishellCore
import MultishellProcess

/// What the engine runs for a session, as the one string libghostty takes and
/// hands to bash as `exec -l <line>` (its Exec.zig).
public enum EngineCommandLine {
  /// Its tab's command, or an override naming a chosen shell. zsh as `$SHELL`
  /// needs none, its hooks riding in on `ZDOTDIR`.
  public static func of(_ session: TerminalSession) -> String? {
    if let command = session.command { return AnyShellQuoting.commandLine(command) }
    return overrideCommand(forShell: session.shellPath).map(AnyShellQuoting.commandLine)
  }

  /// A command line replacing the engine's default shell, `nil` to leave it.
  /// bash goes through `/bin/sh -c`, or libghostty's `exec -l` makes it a login shell.
  static func overrideCommand(
    forShell shellPath: String,
    loginShell: String = ShellChoice.loginShellPath(),
    bashInit: URL = Paths.bashInitFile,
  ) -> [String]? {
    switch shellPath.executableName {
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      return [
        "/bin/sh", "-c",
        AnyShellQuoting.commandLine(
          ["exec"] + ShellLaunch.bashInitArguments(forShell: shellPath, bashInit: bashInit)
        ),
      ]

    case _ where shellPath != loginShell:
      return [shellPath, "-l"]

    default:
      return nil
    }
  }
}
