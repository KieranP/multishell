import Foundation

/// Writes the generated shell-integration files that carry the command-status
/// hooks into this app's terminals.
///
/// zsh sessions point `ZDOTDIR` at `integration/zsh` (see
/// `SessionEnvironment`); bash sessions are launched with
/// `integration/bash/init.bash` (see `ShellLaunch`). The hooks therefore
/// exist only inside the app's terminals, and nothing is written to the
/// user's `~/.zshrc` or `~/.bashrc`. Rewritten each launch so a moved
/// bundle's helper path stays current.
public enum ShellIntegration {
  public static func refresh(
    zshDirectory: URL = Paths.zshIntegrationDirectory,
    bashInit: URL = Paths.bashInitFile,
    helper: String = ClaudeCodeHooks.helperReference
  ) throws {
    try FileManager.default.createDirectory(at: zshDirectory, withIntermediateDirectories: true)
    for (name, contents) in ShellStateHooks.zshIntegrationFiles(helper: helper) {
      try Data(contents.utf8).write(
        to: zshDirectory.appendingPathComponent(name, isDirectory: false), options: .atomic)
    }

    try FileManager.default.createDirectory(
      at: bashInit.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(ShellStateHooks.bashInitFile(helper: helper).utf8).write(
      to: bashInit, options: .atomic)
  }
}
