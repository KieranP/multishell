import Foundation

/// The one line every agent's hooks run, and how to tell it from a user's own.
extension AgentHookCatalogue {
  /// The helper as a hook should reference it: through `$HOME`, so a synced
  /// dotfile still resolves on another machine.
  public static var helperReference: String {
    Paths.helperLink.path.abbreviatingHomeDirectory(as: "$HOME")
  }

  /// Runs the helper rather than `exec`ing it, and exits 0 whatever became of
  /// it; parses in fish as well as sh. See Docs/design/agents.md.
  static func command(agent id: String, helper: String) -> String {
    "[ -x \"\(helper)\" ] && \"\(helper)\" \(subcommand) --agent \(id); exit 0"
  }

  /// Whether a hook line is ours. Whole words, not substrings: the user's own
  /// `multishell-agent-hook-logger` spells both names and Remove used to eat it.
  static func isOurHook(_ command: String) -> Bool {
    let shellPunctuation = CharacterSet(charactersIn: ";&|()")
    let words =
      command
      .split(whereSeparator: { $0.isWhitespace || $0 == "\"" || $0 == "'" })
      .map { $0.trimmingCharacters(in: shellPunctuation) }
    let runsTheHelper = words.contains {
      $0 == Paths.helperName || $0.hasSuffix("/" + Paths.helperName)
    }
    let namesASubcommand = words.contains { $0 == subcommand || $0 == legacySubcommand }
    return runsTheHelper && namesASubcommand
  }
}
