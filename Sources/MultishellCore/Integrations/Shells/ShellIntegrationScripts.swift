import Foundation

/// The integration scripts a shell sources, and the generated startup files
/// carrying them into this app's terminals; see Docs/design/terminals.md.
enum ShellIntegrationScripts {
  private static let helperPlaceholder = "__MULTISHELL_HELPER__"
  /// The agents a shell may report starting, filled in when the file is
  /// generated; see Docs/design/agents.md.
  private static let agentsPlaceholder = "__MULTISHELL_AGENTS__"
  private static let includeDirective = "# include "

  private static let userZdotdirRestore = """
    if [ -n "${MULTISHELL_USER_ZDOTDIR-}" ]; then
      export ZDOTDIR="$MULTISHELL_USER_ZDOTDIR"
    else
      unset ZDOTDIR
    fi
    """

  /// macOS's `/etc/zshrc` names the history file after ZDOTDIR while it is
  /// still ours, so a tab's history left the user's file; see terminals.md.
  private static let historyFromUsersDirectory = """
    case "${HISTFILE-}" in
      "$_multishell_self_zdotdir"/*) HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history" ;;
    esac
    """

  /// The zsh startup files placed in the directory set as a session's
  /// `ZDOTDIR`. Each chains to the user's own first, editing no file of theirs.
  static func forZsh(
    helper: String
  )
    -> [String: String]
  {
    [
      ".zshenv": zshChain(
        userFile: ".zshenv",
        restoresToSelf: true,
        appending: nil,
        capturesUserZdotdir: true,
      ),
      ".zprofile": zshChain(
        userFile: ".zprofile",
        restoresToSelf: true,
        appending: nil,
        capturesUserZdotdir: true,
      ),
      ".zshrc": zshChain(
        userFile: ".zshrc",
        restoresToSelf: false,
        appending: script("init.zsh", in: "zsh", helper: helper),
        restoresHistory: true,
      ),
    ]
  }

  /// Sources the user's `file` under their own `ZDOTDIR`. The last file hands
  /// it back so nested shells skip the chain; the first two may relocate it.
  private static func zshChain(
    userFile: String,
    restoresToSelf: Bool,
    appending extra: String?,
    capturesUserZdotdir: Bool = false,
    restoresHistory: Bool = false,
  ) -> String {
    let header = """
      # Multishell zsh integration, for this app's terminals only. It chains
      # to your own zsh startup files, so nothing here is written to your
      # ~/.zshrc; it runs solely because Multishell set ZDOTDIR for this
      # session.
      _multishell_self_zdotdir="$ZDOTDIR"
      \(userZdotdirRestore)
      \(restoresHistory ? historyFromUsersDirectory : "")
      [ -f "${ZDOTDIR:-$HOME}/\(userFile)" ] && source "${ZDOTDIR:-$HOME}/\(userFile)"
      \(capturesUserZdotdir ? "[ -n \"${ZDOTDIR-}\" ] && export MULTISHELL_USER_ZDOTDIR=\"$ZDOTDIR\"" : "")
      """
    let footer =
      restoresToSelf
      ? """
      export ZDOTDIR="$_multishell_self_zdotdir"
      """
      : """
      # Hand ZDOTDIR back to the user so nested shells do not re-enter this.
      \(userZdotdirRestore)
      """
    return [header, extra, footer].compactMap(\.self).joined(separator: "\n") + "\n"
  }

  /// A bash init file for `--init-file`, which is read instead of `.bashrc`
  /// and skips the profile chain, so this reproduces that chain first.
  static func forBash(helper: String) -> String {
    script("init.bash", in: "bash", helper: helper) + "\n"
  }

  /// A bundled script with its includes joined and placeholders filled, less
  /// its trailing newline so callers place it in a chain.
  private static func script(_ fileName: String, in folder: String, helper: String) -> String {
    includingFiles(in: resource(fileName, in: folder), from: folder)
      .replacingOccurrences(of: helperPlaceholder, with: helper)
      .replacingOccurrences(
        of: agentsPlaceholder,
        with: AgentCatalogue.agents.map(\.executable).sorted().joined(separator: " "),
      )
  }

  /// Each `# include <file>` line replaced by that file from the same folder,
  /// indented as the line is, so the shell reads one file.
  private static func includingFiles(in text: String, from folder: String) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
      let indent = line.prefix { $0 == " " }
      guard line.dropFirst(indent.count).hasPrefix(includeDirective) else { return String(line) }
      let included = resource(
        String(line.dropFirst(indent.count + includeDirective.count)),
        in: folder,
      )
      return included.split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.isEmpty ? "" : indent + $0 }
        .joined(separator: "\n")
    }.joined(separator: "\n")
  }

  private static func resource(_ fileName: String, in folder: String) -> String {
    guard
      let url = Bundle.coreResources.url(
        forResource: fileName,
        withExtension: nil,
        subdirectory: folder,
      ),
      var text = try? String(contentsOf: url, encoding: .utf8)
    else {
      preconditionFailure("\(folder)/\(fileName) is missing from the MultishellCore resources")
    }
    while text.hasSuffix("\n") { text.removeLast() }
    return text
  }
}
