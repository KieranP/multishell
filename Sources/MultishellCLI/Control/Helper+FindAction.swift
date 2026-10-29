import MultishellCore

extension Helper {
  /// TEXT opens a bar on it; one of `--next`, `--previous` and `--close` acts
  /// on the bar up. `command` names `panes find` or `tabs find` in the error.
  static func findAction(
    text: String?,
    _ optionWords: ArraySlice<String>,
    command: String,
    topic: String,
  ) throws -> FindBarAction {
    let options = try CommandOptions(
      optionWords,
      valued: [],
      flags: ["next", "previous", "close"],
      topic: topic,
    )
    let step: FindBarAction? = try direction(in: options, command: command, topic: topic).map {
      direction in direction == .next ? .next : .previous
    }
    let asked =
      [step, options.has("close") ? .close : nil, text.map(FindBarAction.open)].compactMap(\.self)
    guard asked.count == 1, let action = asked.first else {
      throw UsageError("\(command) needs TEXT or one of --next, --previous, --close", topic: topic)
    }
    if case .open(let text) = action, text.isEmpty {
      throw UsageError("\(command) needs TEXT to find", topic: topic)
    }
    return action
  }
}
