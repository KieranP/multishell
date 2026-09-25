import Foundation

/// How to launch a login shell so the command-status hooks reach that session
/// only. zsh rides `ZDOTDIR`, bash `--init-file`; see Docs/design/terminals.md.
public enum ShellLaunch {
  /// The variable Ghostty's zsh bootstrap reads to find the `ZDOTDIR` it
  /// displaced, and hands `ZDOTDIR` back to before the first startup file.
  static let ghosttyZdotdirKey = "GHOSTTY_ZSH_ZDOTDIR"

  /// The shell taking over when an agent tab's agent quits: `exec` plus the
  /// integration a fresh tab gets. Runs under `/bin/sh`; see terminals.md.
  public static func execCommandLine(
    forShell shellPath: String,
    zshDirectory: URL = Paths.zshIntegrationDirectory,
    bashInit: URL = Paths.bashInitFile
  ) -> String {
    let shell = PosixShellQuoting.quote(shellPath)
    switch URL(fileURLWithPath: shellPath).lastPathComponent {
    case "zsh" where FileManager.default.fileExists(atPath: zshDirectory.path):
      let ours = PosixShellQuoting.quote(zshDirectory.path)
      let engine = "\"$GHOSTTY_RESOURCES_DIR/shell-integration/zsh\""
      let script =
        "if [ -f \"${GHOSTTY_RESOURCES_DIR-}/shell-integration/zsh/.zshenv\" ]; then "
        + "ZDOTDIR=\(engine) \(ghosttyZdotdirKey)=\(ours) exec \(shell) -l; "
        + "else ZDOTDIR=\(ours) exec \(shell) -l; fi"
      return "exec /bin/sh -c \(PosixShellQuoting.quote(script))"
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      return "exec \(shell) --init-file \(PosixShellQuoting.quote(bashInit.path)) -i"
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
        "exec \(PosixShellQuoting.quote(shellPath)) --init-file \(PosixShellQuoting.quote(bashInit.path)) -i",
      ]
    case _ where shellPath != loginShell:
      return [shellPath, "-l"]
    default:
      return nil
    }
  }

  /// Points a zsh session's `ZDOTDIR` at the generated directory. Under
  /// Ghostty it sets the pair the engine would have; see terminals.md.
  static func zshIntegration(
    shellPath: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    zshDirectory: URL = Paths.zshIntegrationDirectory,
    engineZshBootstrap: URL? = nil
  ) -> [String: String] {
    let shell = URL(fileURLWithPath: shellPath).lastPathComponent
    guard shell == "zsh",
      FileManager.default.fileExists(atPath: zshDirectory.path)
    else { return [:] }
    var variables = ["ZDOTDIR": zshDirectory.path]
    if let bootstrap = engineZshBootstrap,
      FileManager.default.fileExists(atPath: bootstrap.appendingPathComponent(".zshenv").path)
    {
      variables["ZDOTDIR"] = bootstrap.path
      variables[ghosttyZdotdirKey] = zshDirectory.path
    }
    if let user = environment["ZDOTDIR"], !user.isEmpty {
      variables["MULTISHELL_USER_ZDOTDIR"] = user
    }
    return variables
  }
}
