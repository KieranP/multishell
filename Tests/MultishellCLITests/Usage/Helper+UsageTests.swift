import Foundation
import Testing

@testable import MultishellCLI
@testable import MultishellCore

@Suite
struct HelperUsageTests {
  private static let overviewIndent = "  "

  /// The overview's entries for `topic`: each line naming it and every more
  /// indented one after that.
  private static func overviewEntries(of topic: String) -> String {
    var entries: [String] = []
    var isInEntry = false
    for line in Helper.usage.components(separatedBy: "\n") {
      if line.hasPrefix(overviewIndent + topic + " ") {
        isInEntry = true
      } else if !line.hasPrefix(overviewIndent + " ") {
        isInEntry = false
      }
      if isInEntry { entries.append(line) }
    }
    return entries.joined(separator: "\n")
  }

  /// The first word after `multishell TOPIC` on each of the topic's usage lines.
  private static func subcommands(inUsageOf topic: String) -> Set<String> {
    let prefix = "usage: multishell \(topic) "
    let words = (Helper.usage(of: topic) ?? "").components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.hasPrefix(prefix) }
      .compactMap { $0.dropFirst(prefix.count).split(separator: " ").first }
      .flatMap { $0.split(separator: "|").map(String.init) }
    return Set(words.filter { $0.allSatisfy { $0.isLowercase || $0 == "-" } })
  }

  @Test func theOverviewNamesEverySubcommandACommandsHelpDoes() {
    for command in ControlCommand.allCases {
      let topic = command.rawValue
      let entry = Self.overviewEntries(of: topic)
      let listed = Set(entry.split { !($0.isLowercase || $0 == "-") }.map(String.init))
      for subcommand in Self.subcommands(inUsageOf: topic) {
        #expect(listed.contains(subcommand), "\(topic) \(subcommand) is not in the overview")
      }
    }
  }
}
