import Foundation
import MultishellCore

extension Helper {
  /// The `tabs` subcommands that act inside one tab: a file's, its bar's arrows
  /// and find, and a terminal tab's dividers and dots. `nil` for another word.
  static func runTabContents(
    _ subcommand: String?,
    _ words: [String],
    _ optionWords: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32? {
    let topic = ControlCommand.tabs.rawValue
    switch (subcommand, words.count) {
    case ("open-file", 2):
      try noOptions(optionWords, topic: topic)
      let request = ControlRequest.openFileTab(
        worktree: try worktreeID(words[0], topic: topic),
        path: words[1],
      )
      return try ask(request, environment: environment)

    case ("step", 1):
      let options = try CommandOptions(
        optionWords,
        valued: [],
        flags: ["next", "previous"],
        topic: topic,
      )
      guard let direction = try direction(in: options, command: "tabs step", topic: topic) else {
        throw UsageError("tabs step needs one of --next or --previous", topic: topic)
      }
      let request = ControlRequest.stepToChange(
        tab: try tabOrPaneID(words[0], topic: topic),
        direction: direction,
      )
      return try ask(request, environment: environment)

    case ("find", 1...2):
      let action = try findAction(
        text: words.dropFirst().first,
        optionWords,
        command: "tabs find",
        topic: topic,
      )
      return try findInFileTab(
        try tabOrPaneID(words[0], topic: topic),
        action: action,
        environment: environment,
      )

    case ("clear-status", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .clearTabState(id: try tabOrPaneID(words[0], topic: topic)),
        environment: environment,
      )

    case ("resize", 2):
      throw UsageError(
        "tabs resize takes a SHARE for each side of the split, two at least",
        topic: topic,
      )

    case ("resize", 3...):
      let options = try CommandOptions(optionWords, valued: ["at"], topic: topic)
      let request = ControlRequest.resizeSplit(
        tab: try tabOrPaneID(words[0], topic: topic),
        path: try options["at"].map { try splitPath($0, topic: topic) } ?? [],
        shares: try shares(words.dropFirst(), topic: topic),
      )
      return try ask(request, environment: environment)

    default:
      return nil
    }
  }
}
