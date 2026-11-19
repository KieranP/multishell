import MultishellCore

extension Helper {
  static func runPullRequest(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.pullRequest.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    guard arguments.first == "send", words.isEmpty else {
      throw UsageError("pr needs: send", topic: topic)
    }
    let options = try CommandOptions(
      optionWords,
      valued: ["worktree", "to"],
      flags: ["checks", "threads"],
      topic: topic,
    )
    // Neither flag is the page's Send, both kinds.
    let isOneKind = options.has("checks") != options.has("threads")
    let request = ControlRequest.sendPullRequestFeedback(
      worktree: try worktreeOption(in: options, topic: topic),
      to: try recipientOption(in: options, topic: topic),
      includesChecks: !isOneKind || options.has("checks"),
      includesThreads: !isOneKind || options.has("threads"),
    )
    // Its answer waits on every checked check's log, which can outlast the usual 30 s.
    return try ask(request, environment: environment, timeout: nil)
  }
}
