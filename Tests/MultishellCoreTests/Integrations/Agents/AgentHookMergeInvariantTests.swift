import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Settings files built at random, put through Add and Remove: what was in
/// the file has to come back, since the one promise these make is that they
/// touch nothing they did not write. A failure prints the seed.
@Suite
struct AgentHookMergeInvariantTests {
  private let helper = "$HOME/Library/Application Support/Multishell/bin/multishell"

  @Test(arguments: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89] as [UInt64])
  func addAndRemoveGiveBackTheFileTheyWereGiven(seed: UInt64) throws {
    var rng = SeededGenerator(seed: seed)
    for integration in AgentHooks.integrations where !integration.isOursAlone {
      let before = settings(&rng, events: integration.events.map(\.name))
      let unreadable = integration.unreadableEvents(in: before)

      let added = integration.adding(to: before, helper: helper)
      #expect(
        integration.isInstalled(in: added) == unreadable.isEmpty,
        "seed \(seed) \(integration.id): installed unless an entry was unreadable")
      #expect(
        integration.adding(to: added, helper: helper).keys.count == added.keys.count,
        "seed \(seed) \(integration.id): adding twice adds nothing")

      let after = integration.removing(from: added)
      #expect(
        foreign(in: after) == foreign(in: before),
        "seed \(seed) \(integration.id): a hook of the user's did not come back")
      #expect(
        !integration.isInstalled(in: after) || integration.events.isEmpty,
        "seed \(seed) \(integration.id): ours did not all come out")
      for (key, value) in before where key != "hooks" {
        #expect(
          String(describing: after[key] ?? "") == String(describing: value),
          "seed \(seed) \(integration.id): \(key) was not left alone")
      }
    }
  }

  /// Every hook in the file that is not ours, by the command it runs, plus
  /// whatever sits under an event in a shape these do not write.
  private func foreign(in settings: [String: Any]) -> Set<String> {
    var found: Set<String> = []
    for (event, value) in settings["hooks"] as? [String: Any] ?? [:] {
      guard let groups = value as? [[String: Any]] else {
        found.insert("\(event)=\(String(describing: value))")
        continue
      }
      for group in groups {
        let commands = (group["hooks"] as? [[String: Any]] ?? []).compactMap {
          $0["command"] as? String
        }
        for command in commands where !AgentHooks.isMultishellHook(command) {
          found.insert("\(event)=\(command)")
        }
      }
    }
    return found
  }

  /// A settings file with the shapes these meet: keys of the user's own, a
  /// hooks object holding foreign hooks, ours from an older build, entries
  /// in a shape this cannot read, and events left out altogether.
  private func settings(
    _ rng: inout SeededGenerator, events: [String]
  ) -> [String: Any] {
    var hooks: [String: Any] = [:]
    for event in events + ["PreCompact", "SomethingLater"] {
      switch Int.random(in: 0...5, using: &rng) {
      case 0: break
      case 1: hooks[event] = []
      case 2:
        hooks[event] = [["hooks": [["type": "command", "command": "echo \(event)"]]]]
      case 3:
        let old = "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
        hooks[event] = [["hooks": [["type": "command", "command": old]]]]
      case 4: hooks[event] = "echo \(event)"
      default: hooks[event] = ["command": "echo \(event)"]
      }
    }
    var settings: [String: Any] = ["hooks": hooks]
    if Bool.random(using: &rng) { settings["model"] = "opus" }
    if Bool.random(using: &rng) { settings["permissions"] = ["allow": ["Bash(git *)"]] }
    return settings
  }
}
