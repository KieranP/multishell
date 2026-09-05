import Foundation

/// How to launch a plain login shell so the command-status hooks are injected
/// for that session only.
///
/// zsh carries its hooks through `ZDOTDIR` in the environment (see
/// `SessionEnvironment`), so its arguments are the plain login form. bash has
/// no such variable, so it is launched with `--init-file` pointing at the
/// generated init; the shell is then interactive but not login, and the init
/// reproduces the login startup. Any other shell is launched plainly, with no
/// hooks.
public enum ShellLaunch {
  /// Arguments for launching `shellPath` as the tab's shell, for a host that
  /// builds the whole argv itself (SwiftTerm).
  public static func arguments(
    forShell shellPath: String, bashInit: URL = Paths.bashInitFile
  ) -> [String] {
    switch URL(fileURLWithPath: shellPath).lastPathComponent {
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      // Interactive, reading our init in place of ~/.bashrc; not login, so
      // the init reproduces the profile chain.
      return ["--init-file", bashInit.path, "-i"]
    default:
      return ["-l"]
    }
  }

  /// The shell that takes over when an agent tab's agent quits, as a command
  /// fragment: `exec` plus the same integration a fresh tab gets. Our `.zshrc`
  /// hands `ZDOTDIR` back to the user, so it is set again here; bash gets its
  /// init file. `.exec` alone otherwise.
  public static func execCommandLine(
    forShell shellPath: String,
    zshIntegration: URL = Paths.zshIntegrationDirectory,
    bashInit: URL = Paths.bashInitFile
  ) -> String {
    let shell = ShellQuoting.quote(shellPath)
    switch URL(fileURLWithPath: shellPath).lastPathComponent {
    case "zsh" where FileManager.default.fileExists(atPath: zshIntegration.path):
      return "ZDOTDIR=\(ShellQuoting.quote(zshIntegration.path)) exec \(shell) -l"
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      return "exec \(shell) --init-file \(ShellQuoting.quote(bashInit.path)) -i"
    default:
      return "exec \(shell) -l"
    }
  }

  /// A full command line to run in place of the engine's default shell, for a
  /// host that takes one command string (Ghostty). `nil` means "leave the
  /// default", which is right for zsh (its hooks ride in on `ZDOTDIR`) and
  /// for a shell with no integration.
  ///
  /// bash goes through `/bin/sh -c 'exec bash …'`. Ghostty keys its own bash
  /// injection on the command's first word: given `bash --init-file X` it
  /// swallows the init into `GHOSTTY_BASH_RCFILE`, adds `--posix` and points
  /// `ENV` at its bootstrap, and macOS's bash 3.2 in that mode reads neither,
  /// so no hooks at all attach. `sh` gets no injection and hands bash our
  /// init intact; Ghostty's OSC 133 marks are lost for bash, which the hooks
  /// more than replace.
  public static func overrideCommand(
    forShell shellPath: String, bashInit: URL = Paths.bashInitFile
  ) -> [String]? {
    switch URL(fileURLWithPath: shellPath).lastPathComponent {
    case "bash" where FileManager.default.fileExists(atPath: bashInit.path):
      return [
        "/bin/sh", "-c",
        "exec \(ShellQuoting.quote(shellPath)) --init-file \(ShellQuoting.quote(bashInit.path)) -i",
      ]
    default:
      return nil
    }
  }
}
