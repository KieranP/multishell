import Foundation
import MultishellCore

extension Helper {
  static func runTabs(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = "tabs"
    // Its `--` starts a command, not more words.
    if arguments.first == "open" {
      return try ask(.newTab(try tabOrder(arguments.dropFirst())), environment: environment)
    }
    let (words, options) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 0...1):
      try noOptions(options, topic: topic)
      return try ask(
        .listTabs(worktree: try words.first.map { try worktreeID($0, topic: topic) }),
        environment: environment,
      )

    case ("show", 1):
      try noOptions(options, topic: topic)
      return try ask(
        .describeTab(id: try tabOrPaneID(words[0], topic: topic)),
        environment: environment,
      )

    case ("select", 1):
      try noOptions(options, topic: topic)
      return try ask(
        .selectTab(id: try tabOrPaneID(words[0], topic: topic)),
        environment: environment,
      )

    case ("close", 1):
      let force = try isForced(options, topic: topic)
      return try ask(
        .closeTab(id: try tabOrPaneID(words[0], topic: topic), force: force),
        environment: environment,
      )

    case ("move", 1):
      let options = try CommandOptions(options, valued: ["before", "after"], topic: topic)
      guard let anchor = options["before"] ?? options["after"],
        (options["before"] == nil) != (options["after"] == nil)
      else {
        throw UsageError("tabs move needs one of --before TAB_ID or --after TAB_ID", topic: topic)
      }
      let request = ControlRequest.moveTab(
        id: try tabOrPaneID(words[0], topic: topic),
        before: options["before"] != nil,
        anchor: try tabOrPaneID(anchor, topic: topic),
      )
      return try ask(request, environment: environment)

    case ("rename", 1...2):
      try noOptions(options, topic: topic)
      let title = givenName(in: words)
      return try ask(
        .renameTab(id: try tabOrPaneID(words[0], topic: topic), title: title),
        environment: environment,
      )

    default:
      throw UsageError("tabs needs: list, open, show, select, close, move or rename", topic: topic)
    }
  }

  private static func tabOrder(_ arguments: ArraySlice<String>) throws -> NewTabOrder {
    let topic = "tabs"
    let (head, command) = splitAtDoubleDash(arguments)
    let (words, optionWords) = positionals(head)
    guard words.count == 1 else {
      throw UsageError("tabs open takes one WORKTREE_ID; a command goes after --", topic: topic)
    }
    let options = try CommandOptions(optionWords, valued: ["agent", "prompt"], topic: topic)
    if let command, command.isEmpty {
      throw UsageError("-- needs a command after it", topic: topic)
    }
    if command != nil, options["agent"] != nil || options["prompt"] != nil {
      throw UsageError("a tab runs an agent or a command, not both", topic: topic)
    }
    return NewTabOrder(
      worktreeID: try worktreeID(words[0], topic: topic),
      agentID: options["agent"],
      task: options["prompt"],
      command: command.map(Array.init),
    )
  }
}
