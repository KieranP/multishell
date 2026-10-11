import Foundation
import TestScratch

protocol AgentHookFixtures {}

extension AgentHookFixtures {
  var helper: String { "$HOME/Library/Application Support/Multishell/bin/multishell" }

  /// The line the first builds wrote, which settings files may still hold.
  var retiredClaudeHookLine: String {
    "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
  }

  /// Each event holding one group with `command` as its only hook.
  func groups(_ events: [String], command: String) -> [String: Any] {
    var hooks: [String: Any] = [:]
    for event in events {
      hooks[event] = [["hooks": [["type": "command", "command": command]]]]
    }
    return hooks
  }

  /// Where a settings file would go, alone in a scratch directory the caller removes.
  func scratchSettingsFile(
    named name: String = "settings.json"
  ) throws -> (directory: URL, file: URL) {
    let directory = try Scratch.directory("hooks")
    return (directory, directory.appendingPathComponent(name))
  }
}
