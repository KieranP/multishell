import Foundation
import MultishellCore

extension Helper {
  /// The commands on a pane's terminal: typing, reading and finding; `nil`
  /// for any other.
  static func runPaneTerminal(
    _ command: String?,
    _ words: [String],
    _ options: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32? {
    let topic = "panes"
    switch (command, words.count) {
    case ("type", 2):
      return try typeIntoPane(
        try tabOrPaneID(words[0], topic: topic),
        words[1],
        options,
        environment: environment,
      )

    case ("read", 1):
      return try readPane(
        try tabOrPaneID(words[0], topic: topic),
        options,
        environment: environment,
      )

    case ("wait", 1):
      return try waitForPane(
        try tabOrPaneID(words[0], topic: topic),
        options,
        environment: environment,
      )

    case ("paste", 2):
      try noOptions(options, topic: topic)
      return try pasteIntoPane(
        try tabOrPaneID(words[0], topic: topic),
        words[1],
        environment: environment,
      )

    case ("key", 2...):
      try noOptions(options, topic: topic)
      return try pressKeys(
        words.dropFirst(),
        in: try tabOrPaneID(words[0], topic: topic),
        environment: environment,
      )

    case ("find", 1...2):
      return try findInPane(
        try tabOrPaneID(words[0], topic: topic),
        text: words.dropFirst().first,
        options,
        environment: environment,
      )

    default:
      return nil
    }
  }
}
