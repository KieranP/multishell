import MultishellCore

extension Helper {
  static func runFiles(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.files.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    try noOptions(optionWords, topic: topic)
    switch (arguments.first, words.count) {
    case ("list", 0): return try ask(.listFiles, environment: environment)

    case ("filter", 0...1):
      return try ask(.filterFiles(text: words.first ?? ""), environment: environment)

    case ("expand", 1), ("collapse", 1):
      let request = ControlRequest.setFilesFolderExpanded(
        path: words[0],
        expanded: arguments.first == "expand",
      )
      return try ask(request, environment: environment)

    default:
      throw UsageError(
        "files needs: list, filter [TEXT], expand PATH or collapse PATH",
        topic: topic,
      )
    }
  }
}
