import Foundation

/// How a chosen shell is stored and resolved. The value is the shell's path;
/// the login shell has no path of its own because it is whatever `$SHELL`
/// says on the machine the state file is opened on.
public enum ShellCatalogue {
  /// A project override that means "the login shell here" while the global
  /// names another. A global value of `nil` means the same.
  public static let loginShellID = "login"

  /// Shells worth looking for on the login shell's PATH beyond `/etc/shells`,
  /// which Homebrew installs do not always register.
  public static let searched = ["zsh", "bash", "fish", "nu"]

  /// The path in force for a project, or `nil` for `$SHELL`, whichever side
  /// said so.
  public static func effectivePath(global: String?, override: String?) -> String? {
    let chosen = override ?? global
    guard let chosen, !chosen.isEmpty, chosen != loginShellID else { return nil }
    return chosen
  }

  /// `$SHELL`, or `/bin/zsh` where the environment has none, which is what
  /// both engines assumed before shells could be chosen.
  public static func loginShellPath(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String {
    let shell = environment["SHELL"] ?? ""
    return shell.isEmpty ? "/bin/zsh" : shell
  }
}
