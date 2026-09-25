import Foundation
import MultishellCore
import MultishellProcess

/// The line a tab runs in place of a plain shell, an agent's or an editor's:
/// through the login shell for its PATH, a shell taking over when it quits.
enum TabCommand {
  static func running(
    _ arguments: [String],
    shell: ShellInvocation,
    exec: String
  ) -> [String] {
    // The login shell may be tcsh or fish, which read a `!` or a `\` in single quotes.
    line(arguments.map(AnyShellQuoting.quote).joined(separator: " "), shell: shell, exec: exec)
  }

  /// A custom entry is a shell line as the user typed it, the values its
  /// placeholders read set in the environment around the shell.
  static func running(
    customLine: ShellLine,
    shell: ShellInvocation,
    exec: String
  ) -> [String]? {
    guard !customLine.text.isEmpty else { return nil }
    return customLine.prefixing(line(customLine.text, shell: shell, exec: exec))
  }

  private static func line(
    _ commandLine: String, shell: ShellInvocation, exec: String
  ) -> [String] {
    [shell.executable.path] + shell.arguments + ["\(commandLine); \(exec)"]
  }
}
