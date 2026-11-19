import MultishellCore

extension Helper {
  static func runCI(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.ciRuns.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    guard arguments.first == "send", words.isEmpty else {
      throw UsageError("ci needs: send", topic: topic)
    }
    let options = try CommandOptions(optionWords, valued: ["worktree", "to"], topic: topic)
    let request = ControlRequest.sendCIFailures(
      worktree: try worktreeOption(in: options, topic: topic),
      to: try recipientOption(in: options, topic: topic),
    )
    return try ask(request, environment: environment)
  }
}
