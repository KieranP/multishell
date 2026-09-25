import Foundation

/// A shell and the flags that come before the command line it is handed.
public struct ShellInvocation: Equatable, Sendable {
  public let executable: URL
  public let arguments: [String]

  init(executable: URL, arguments: [String]) {
    self.executable = executable
    self.arguments = arguments
  }

  /// Shells known to take `-l -i -c`. Another one (nu, xonsh, elvish) would
  /// fail on the flags, so it gets `/bin/sh` instead.
  static let interactiveLoginShells: Set<String> = [
    "sh", "bash", "zsh", "fish", "dash", "ksh", "mksh",
  ]

  /// csh and tcsh take `-l` only as their one flag, so beside `-c` they get
  /// `-i` alone, which reads `.cshrc` and `.tcshrc` but not `.login`.
  static let loginFlagRefusers: Set<String> = ["tcsh", "csh"]

  /// Runs in place of a shell that would fail on the flags, reading no
  /// startup files.
  static let fallbackShell = URL(fileURLWithPath: "/bin/sh")

  /// The user's shell, interactive and login, so a script sees a terminal's
  /// PATH: additions live in `.zprofile` for some and `.zshrc` for others.
  public static func userShell(at path: String) -> ShellInvocation {
    guard FileManager.default.isExecutableFile(atPath: path) else {
      return ShellInvocation(executable: fallbackShell, arguments: ["-c"])
    }
    let name = URL(fileURLWithPath: path).lastPathComponent
    if loginFlagRefusers.contains(name) {
      return ShellInvocation(executable: URL(fileURLWithPath: path), arguments: ["-i", "-c"])
    }
    guard interactiveLoginShells.contains(name) else {
      return ShellInvocation(executable: fallbackShell, arguments: ["-c"])
    }
    return ShellInvocation(executable: URL(fileURLWithPath: path), arguments: ["-l", "-i", "-c"])
  }

  /// The shell is interactive, so an inherited HISTFILE is its history: bash
  /// truncates it and ksh rewrites it in its own format; see hooks.md.
  static func historyless(_ environment: [String: String]) -> [String: String] {
    environment.merging(["HISTFILE": ""]) { _, empty in empty }
  }
}
