import Foundation
import TestScratch

protocol AgentHookFixtures {}

extension AgentHookFixtures {
  var helper: String { "$HOME/Library/Application Support/Multishell/bin/multishell" }

  /// The hook line the first builds wrote, which settings files still hold.
  var legacyClaudeHookLine: String {
    "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
  }

  /// Where a settings file would go, alone in a scratch directory the caller removes.
  func scratchSettingsFile(
    named name: String = "settings.json"
  ) throws -> (directory: URL, file: URL) {
    let directory = try Scratch.directory("hooks")
    return (directory, directory.appendingPathComponent(name))
  }
}
