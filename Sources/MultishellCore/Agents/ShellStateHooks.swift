import Foundation

/// The command-status hooks a shell runs so the dots follow every command,
/// and the generated startup files that carry them into this app's terminals.
///
/// A `preexec`/`precmd` pair calls the helper's `command-started` and
/// `command-finished --exit $?`; the helper maps the code. Injected per
/// session, silently: zsh through a `ZDOTDIR` that chains to the user's own
/// files, bash through `--init-file`. Nothing is written to a file the user
/// owns, and the hooks do nothing outside a Multishell terminal
/// (`MULTISHELL_SESSION` unset) or when the helper is missing.
///
/// The zsh script also tells Ghostty a click in its prompt may move the
/// cursor; see `hooks.zsh`. Ghostty's own zsh files are entered before these,
/// through the pair `SessionEnvironment.zshIntegration` sets.
///
/// The scripts themselves are `Resources/hooks.zsh` and `Resources/init.bash`,
/// plain shell files with `__MULTISHELL_HELPER__` where the helper's path
/// goes, so they read and lint as shell rather than as escaped Swift.
public enum ShellStateHooks {
  static let helperPlaceholder = "__MULTISHELL_HELPER__"

  // MARK: - Per-session injection (zsh)

  /// The zsh startup files to place in a directory this app sets as a
  /// session's `ZDOTDIR`. Each chains to the user's own file first, so their
  /// config loads unchanged, then `.zshrc` adds the command-status hooks and
  /// hands `ZDOTDIR` back so nested shells are untouched. This is how the
  /// hooks reach a terminal without editing any file the user owns.
  public static func zshIntegrationFiles(
    helper: String = ClaudeCodeHooks.helperReference
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

  /// Sources the user's `file`, with `ZDOTDIR` pointed at the user's own
  /// directory while it runs. `restoreToSelf` keeps our directory in force
  /// for the next startup file; the last one instead hands `ZDOTDIR` back to
  /// the user so a nested shell does not re-enter this chain.
  /// `capturesUserZdotdir`: the user's `.zshenv` may itself relocate
  /// `ZDOTDIR`; the directory it leaves is where their `.zprofile` and
  /// `.zshrc` live, so it is recorded for the later files to chain to.
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

  /// A bash init file to launch with `--init-file`. Interactive bash reads
  /// it instead of `~/.bashrc` and, since it is not a login shell, would skip
  /// the profile chain, so this reproduces that chain first, then the user's
  /// `.bashrc`, then adds the hooks. Nothing is written to the user's files.
  public static func bashInitFile(helper: String = ClaudeCodeHooks.helperReference) -> String {
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

  /// SwiftPM's `Bundle.module` looks beside the executable and in the build
  /// directory, not in an app bundle's `Contents/Resources`, which is where
  /// `make-app.sh` puts the resource bundles. Try there first; the generated
  /// accessor covers `swift test`, the helper and Linux.
  private static let resourceBundle: Bundle = {
    if let resources = Bundle.main.resourceURL {
      let inApp = resources.appendingPathComponent(
        "multishell_MultishellCore.bundle", isDirectory: true)
      if let bundle = Bundle(url: inApp),
        bundle.url(forResource: "hooks", withExtension: "zsh") != nil
      {
        return bundle
      }
    }
    return Bundle.module
  }()
}
