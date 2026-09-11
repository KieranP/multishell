import Foundation

/// How a chosen shell is stored and resolved. The value is its path; the
/// login shell has none, being whatever `$SHELL` says on that machine.
public enum ShellCatalogue {
  /// A project override that means "the login shell here" while the global
  /// names another. A global value of `nil` means the same.
  public static let loginShellID = "login"
  /// The path the user typed in settings, `Workspace.customShellPath`. A
  /// project override of this id means that same path.
  public static let customID = "custom"

  /// Shells worth looking for on the login shell's PATH beyond `/etc/shells`,
  /// which Homebrew installs do not always register.
  public static let searched = ["zsh", "bash", "fish", "nu"]

  /// The path in force for a project, or `nil` for `$SHELL`. `customID`
  /// resolves to `customPath`, and blank is `$SHELL` too.
  public static func effectivePath(
    global: String?, override: String?, customPath: String = ""
  ) -> String? {
    let chosen = override ?? global
    guard let chosen, !chosen.isEmpty, chosen != loginShellID else { return nil }
    guard chosen == customID else { return chosen }
    let path = customPath.trimmingCharacters(in: .whitespaces)
    return path.isEmpty ? nil : path
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
