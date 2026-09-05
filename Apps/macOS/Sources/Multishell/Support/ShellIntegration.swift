import Foundation
import MultishellCore

/// Writes the generated shell-integration files that carry the command-status
/// hooks into this app's terminals.
///
/// zsh sessions point `ZDOTDIR` at `integration/zsh` (see
/// `SessionEnvironment`); bash sessions are launched with
/// `integration/bash/init.bash`. The hooks therefore exist only inside the
/// app's terminals, and nothing is written to the user's `~/.zshrc` or
/// `~/.bashrc`. Rewritten each launch so a moved bundle's helper path stays
/// current.
enum ShellIntegration {
  static func refresh() throws {
    let zsh = Paths.zshIntegrationDirectory
    try FileManager.default.createDirectory(at: zsh, withIntermediateDirectories: true)
    for (name, contents) in ShellStateHooks.zshIntegrationFiles() {
      try Data(contents.utf8).write(
        to: zsh.appendingPathComponent(name, isDirectory: false), options: .atomic)
    }

    let bashInit = Paths.bashInitFile
    try FileManager.default.createDirectory(
      at: bashInit.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(ShellStateHooks.bashInitFile().utf8).write(to: bashInit, options: .atomic)
  }
}
