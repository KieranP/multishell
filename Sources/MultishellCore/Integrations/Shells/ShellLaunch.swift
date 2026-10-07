import Foundation

/// How to launch a login shell so the command-status hooks reach that session
/// only. zsh rides `ZDOTDIR`, bash `--init-file`; see Docs/design/terminals.md.
public enum ShellLaunch {
  /// The shell taking over when an agent tab's agent quits: `exec` plus the
  /// integration a fresh tab gets, as words for the caller to quote.
  public static func execArguments(
    forShell shellPath: String,
    zshDirectory: URL = Paths.zshIntegrationDirectory,
    bashInit: URL = Paths.bashInitFile
  ) -> [String] {
    switch shellPath.executableName {
    case "zsh" where FileManager.default.fileExists(atPath: zshDirectory.path):
      // Through env: fish and csh take no `VAR=value` before a command.
      return ["exec", "env", "ZDOTDIR=\(zshDirectory.path)", shellPath, "-l"]
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      return ["exec"] + bashInitArguments(shell: shellPath, bashInit: bashInit)
    default:
      return ["exec", shellPath, "-l"]
    }
  }

  /// Only zsh and bash are given the marks that say a command finished; see
  /// COMPAT.md.
  public static func reportsFinishedCommands(_ shellPath: String) -> Bool {
    ["zsh", "bash"].contains(shellPath.executableName)
  }

  /// Points a zsh session's `ZDOTDIR` at the generated directory, and says
  /// where the user's was so ours can chain to it; see terminals.md.
  static func zshEnvironment(
    forShell shellPath: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    zshDirectory: URL = Paths.zshIntegrationDirectory
  ) -> [String: String] {
    guard shellPath.executableName == "zsh",
      FileManager.default.fileExists(atPath: zshDirectory.path)
    else { return [:] }
    var variables = ["ZDOTDIR": zshDirectory.path]
    if let user = environment["ZDOTDIR"], !user.isEmpty {
      variables["MULTISHELL_USER_ZDOTDIR"] = user
    }
    return variables
  }

  /// bash told to read the generated init file, as an interactive shell.
  public static func bashInitArguments(shell shellPath: String, bashInit: URL) -> [String] {
    [shellPath, "--init-file", bashInit.path, "-i"]
  }
}
