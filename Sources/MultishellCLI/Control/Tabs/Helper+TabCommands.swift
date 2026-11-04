import Foundation
import MultishellCore

extension Helper {
  static func runTabs(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.tabs.rawValue
    // Its `--` starts a command, not more words.
    if arguments.first == "open" {
      return try ask(.newTab(try tabOrder(arguments.dropFirst())), environment: environment)
    }
    let (words, optionWords) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 0...1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .listTabs(worktree: try words.first.map { try worktreeID($0, topic: topic) }),
        environment: environment,
      )

    case ("show", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .describeTab(id: try tabOrPaneID(words[0], topic: topic)),
        environment: environment,
      )

    case ("select", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .selectTab(id: try tabOrPaneID(words[0], topic: topic)),
        environment: environment,
      )

    case ("close", 1):
      let force = try isForced(optionWords, topic: topic)
      return try ask(
        .closeTab(id: try tabOrPaneID(words[0], topic: topic), force: force),
        environment: environment,
      )

    case ("move", 1):
      let request = try tabMove(try tabOrPaneID(words[0], topic: topic), optionWords)
      return try ask(request, environment: environment)

    case ("rename", 1...2):
      try noOptions(optionWords, topic: topic)
      let title = givenName(in: words)
      return try ask(
        .renameTab(id: try tabOrPaneID(words[0], topic: topic), title: title),
        environment: environment,
      )

    default:
      guard
        let status = try runTabContents(
          arguments.first,
          words,
          optionWords,
          environment: environment,
        )
      else {
        throw UsageError(
          "tabs needs: list, open, open-file, show, select, close, move, rename, resize, "
            + "clear-status, step or find",
          topic: topic,
        )
      }
      return status
    }
  }

  /// One of `--before TAB_ID`, `--after TAB_ID`, `--worktree WORKTREE_ID` and
  /// `--new-group`, as the drag or the menu item it stands for.
  private static func tabMove(
    _ id: UUID,
    _ optionWords: ArraySlice<String>,
  ) throws -> ControlRequest {
    let topic = ControlCommand.tabs.rawValue
    let usage =
      "tabs move needs one of --before TAB_ID, --after TAB_ID, --worktree WORKTREE_ID "
      + "or --new-group"
    let options = try CommandOptions(
      optionWords,
      valued: ["before", "after", "worktree"],
      flags: ["new-group"],
      topic: topic,
    )
    let beside = try placement(in: options, usage: usage, topic: topic)
    let asked = [beside != nil, options["worktree"] != nil, options.has("new-group")]
    guard asked.filter(\.self).count == 1 else { throw UsageError(usage, topic: topic) }
    if let (placement, anchor) = beside {
      return .moveTab(id: id, placement: placement, anchor: try tabOrPaneID(anchor, topic: topic))
    }
    if let worktree = options["worktree"] {
      return .moveTabToWorktree(id: id, worktree: try worktreeID(worktree, topic: topic))
    }
    return .moveTabToNewGroup(id: id)
  }

  private static func tabOrder(_ arguments: ArraySlice<String>) throws -> NewTabOrder {
    let topic = ControlCommand.tabs.rawValue
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
