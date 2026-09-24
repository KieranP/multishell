import Foundation

/// How to launch a login shell so the command-status hooks reach that session
/// only. zsh rides `ZDOTDIR`, bash `--init-file`; see Docs/design/terminals.md.
public enum ShellLaunch {
  /// The shell taking over when an agent tab's agent quits: `exec` plus the
  /// integration a fresh tab gets. Runs under `/bin/sh`; see terminals.md.
  public static func execCommandLine(
    forShell shellPath: String,
    zshIntegration: URL = Paths.zshIntegrationDirectory,
    bashInit: URL = Paths.bashInitFile
  ) -> String {
    let shell = ShellQuoting.quote(shellPath)
    switch URL(fileURLWithPath: shellPath).lastPathComponent {
    case "zsh" where FileManager.default.fileExists(atPath: zshIntegration.path):
      let ours = ShellQuoting.quote(zshIntegration.path)
      let engine = "\"$GHOSTTY_RESOURCES_DIR/shell-integration/zsh\""
      let script =
        "if [ -f \"${GHOSTTY_RESOURCES_DIR-}/shell-integration/zsh/.zshenv\" ]; then "
        + "ZDOTDIR=\(engine) \(SessionEnvironment.ghosttyZdotdirKey)=\(ours) exec \(shell) -l; "
        + "else ZDOTDIR=\(ours) exec \(shell) -l; fi"
      return "exec /bin/sh -c \(ShellQuoting.quote(script))"
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      return "exec \(shell) --init-file \(ShellQuoting.quote(bashInit.path)) -i"
    default:
      return "exec \(shell) -l"
    }
  }

  /// Only zsh and bash are given the marks that say a command finished; see
  /// COMPAT.md.
  public static func reportsFinishedCommands(_ shellPath: String) -> Bool {
    ["zsh", "bash"].contains(URL(fileURLWithPath: shellPath).lastPathComponent)
  }

  /// A command line replacing the engine's default shell, `nil` to leave it.
  /// bash goes through `/bin/sh -c`; see Docs/design/terminals.md.
  public static func overrideCommand(
    forShell shellPath: String,
    loginShell: String = ShellCatalogue.loginShellPath(),
    bashInit: URL = Paths.bashInitFile
  ) -> [String]? {
    switch URL(fileURLWithPath: shellPath).lastPathComponent {
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      return [
        "/bin/sh", "-c",
        "exec \(ShellQuoting.quote(shellPath)) --init-file \(ShellQuoting.quote(bashInit.path)) -i",
      ]
    case _ where shellPath != loginShell:
      return [shellPath, "-l"]
    default:
      return nil
    }
  }
}
