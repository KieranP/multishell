import Foundation

/// The command-status hooks a shell runs, and the generated startup files
/// carrying them into this app's terminals; see docs/design/terminals.md.
public enum ShellStateHooks {
  static let helperPlaceholder = "__MULTISHELL_HELPER__"

  // MARK: - Per-session injection (zsh)

  /// The zsh startup files placed in the directory set as a session's
  /// `ZDOTDIR`. Each chains to the user's own first, editing no file of theirs.
  public static func zshIntegrationFiles(
    helper: String = AgentHooks.helperReference
  )
    -> [String: String]
  {
    [
      ".zshenv": zshChain(
        userFile: ".zshenv", restoreToSelf: true, capturesUserZdotdir: true, appending: nil),
      ".zprofile": zshChain(userFile: ".zprofile", restoreToSelf: true, appending: nil),
      ".zshrc": zshChain(
        userFile: ".zshrc", restoreToSelf: false,
        appending: script("hooks", extension: "zsh", helper: helper)),
    ]
  }

  /// Sources the user's `file` under their own `ZDOTDIR`. The last file hands
  /// it back so nested shells skip the chain; `.zshenv` may relocate it.
  private static func zshChain(
    userFile: String, restoreToSelf: Bool, capturesUserZdotdir: Bool = false,
    appending extra: String?
  ) -> String {
    let header = """
      # Multishell zsh integration, for this app's terminals only. It chains
      # to your own zsh startup files, so nothing here is written to your
      # ~/.zshrc; it runs solely because Multishell set ZDOTDIR for this
      # session.
      _multishell_self_zdotdir="$ZDOTDIR"
      if [ -n "${MULTISHELL_USER_ZDOTDIR-}" ]; then
        export ZDOTDIR="$MULTISHELL_USER_ZDOTDIR"
      else
        unset ZDOTDIR
      fi
      [ -f "${ZDOTDIR:-$HOME}/\(userFile)" ] && source "${ZDOTDIR:-$HOME}/\(userFile)"
      \(capturesUserZdotdir ? "[ -n \"${ZDOTDIR-}\" ] && export MULTISHELL_USER_ZDOTDIR=\"$ZDOTDIR\"" : "")
      """
    let footer =
      restoreToSelf
      ? """
      export ZDOTDIR="$_multishell_self_zdotdir"
      """
      : """
      # Hand ZDOTDIR back to the user so nested shells do not re-enter this.
      if [ -n "${MULTISHELL_USER_ZDOTDIR-}" ]; then
        export ZDOTDIR="$MULTISHELL_USER_ZDOTDIR"
      else
        unset ZDOTDIR
      fi
      """
    return [header, extra, footer].compactMap { $0 }.joined(separator: "\n") + "\n"
  }

  // MARK: - Per-session injection (bash)

  /// A bash init file for `--init-file`, which is read instead of `.bashrc`
  /// and skips the profile chain, so this reproduces that chain first.
  public static func bashInitFile(helper: String = AgentHooks.helperReference) -> String {
    script("init", extension: "bash", helper: helper) + "\n"
  }

  // MARK: - Resources

  /// A script from the resource bundle with the helper's path filled in,
  /// without its trailing newline so callers place it in a chain.
  private static func script(_ name: String, extension: String, helper: String) -> String {
    guard let url = resourceBundle.url(forResource: name, withExtension: `extension`),
      var text = try? String(contentsOf: url, encoding: .utf8)
    else {
      preconditionFailure("\(name).\(`extension`) is missing from the MultishellCore resources")
    }
    while text.hasSuffix("\n") { text.removeLast() }
    return text.replacingOccurrences(of: helperPlaceholder, with: helper)
  }

  private static let resourceBundle = PackageBundle.holding(
    "hooks", withExtension: "zsh", named: "multishell_MultishellCore.bundle", or: .module)
}
