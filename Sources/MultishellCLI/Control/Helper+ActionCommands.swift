import MultishellCore

extension Helper {
  static func runActions(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.actions.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .listActions(worktree: try worktreeID(words[0], topic: topic)),
        environment: environment,
      )

    case ("run", 2):
      let options = try CommandOptions(
        optionWords,
        valued: [],
        flags: ["restart", "force"],
        topic: topic,
      )
      return try ask(
        .runAction(
          worktree: try worktreeID(words[0], topic: topic),
          name: words[1],
          restart: options.has("restart"),
          force: options.has("force"),
        ),
        environment: environment,
      )

    default:
      throw UsageError("actions needs: list WORKTREE_ID, or run WORKTREE_ID NAME", topic: topic)
    }
  }
}
