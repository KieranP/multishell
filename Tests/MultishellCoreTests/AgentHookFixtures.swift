import Foundation

protocol AgentHookFixtures {}

extension AgentHookFixtures {
  var helper: String { "$HOME/Library/Application Support/Multishell/bin/multishell" }

  /// The hook line the first builds wrote, which settings files still hold.
  var legacyClaudeHookLine: String {
    "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
  }
}
