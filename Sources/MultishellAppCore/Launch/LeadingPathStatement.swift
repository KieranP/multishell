import Foundation
import MultishellCore
import MultishellProcess

/// The statement a tab's line opens with, in the login shell's own syntax: its
/// profile's `path_helper` moved the app's entries back. See terminals.md.
enum LeadingPathStatement {
  /// Empty where no profile ran: csh reads `.login` only as a login shell,
  /// which `-i -c` is not, and `/bin/sh -c` reads nothing.
  static func line(for shell: ShellInvocation) -> String {
    guard shell.arguments.contains("-l") else { return "" }
    let name = shell.executable.lastPathComponent
    return ShellIntegrationScripts.leadingPathStatement(forShellNamed: name) + "\n"
  }
}
