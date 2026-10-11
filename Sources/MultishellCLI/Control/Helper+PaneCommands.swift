import Foundation
import MultishellCore

extension Helper {
  static func runPanes(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = "panes"
    let (words, options) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("split", 0):
      let options = try CommandOptions(options, valued: ["tab"], flags: ["down"], topic: topic)
      let tab = try options["tab"].map { try tabOrPaneID($0, topic: topic) }
      let axis: SplitAxis = options.has("down") ? .vertical : .horizontal
      return try ask(.splitPane(axis: axis, tab: tab), environment: environment)

    case ("select", 1):
      try noOptions(options, topic: topic)
      return try ask(
        .selectPane(id: try tabOrPaneID(words[0], topic: topic)),
        environment: environment,
      )

    case ("close", 1):
      let force = try isForced(options, topic: topic)
      return try ask(
        .closePane(id: try tabOrPaneID(words[0], topic: topic), force: force),
        environment: environment,
      )

    case ("show", 1):
      try noOptions(options, topic: topic)
      return try ask(
        .describePane(id: try tabOrPaneID(words[0], topic: topic)),
        environment: environment,
      )

    default:
      let status = try runPaneTerminal(arguments.first, words, options, environment: environment)
      guard let status else {
        throw UsageError(
          "panes needs: split, select, close, type, paste, key, show, read, wait or find",
          topic: topic,
        )
      }
      return status
    }
  }
}
