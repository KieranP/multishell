import Foundation
import MultishellCore

extension Helper {
  /// The `tabs` subcommands that open a file's tab or the All changes tab.
  /// `nil` for another word.
  static func runTabOpenings(
    _ subcommand: String?,
    _ words: [String],
    _ optionWords: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32? {
    let topic = ControlCommand.tabs.rawValue
    switch (subcommand, words.count) {
    case ("open-all-changes", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .openAllChangesTab(worktree: try worktreeID(words[0], topic: topic)),
        environment: environment,
      )

    case ("open-file", 2):
      try noOptions(optionWords, topic: topic)
      let request = ControlRequest.openFileTab(
        worktree: try worktreeID(words[0], topic: topic),
        path: words[1],
      )
      return try ask(request, environment: environment)

    default:
      return nil
    }
  }
}
