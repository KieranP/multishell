import MultishellCore

extension Helper {
  static func runConfig(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = "config"
    let rest = arguments.dropFirst()
    switch arguments.first {
    case "global":
      return try ask(try globalRequest(Array(rest), topic: topic), environment: environment)

    case "project":
      guard let first = rest.first else {
        throw UsageError("config project needs a PROJECT_ID", topic: topic)
      }
      let project = try projectID(first, topic: topic)
      let request = try projectRequest(Array(rest.dropFirst()), project: project, topic: topic)
      return try ask(request, environment: environment)

    default:
      throw UsageError("config needs global or project", topic: topic)
    }
  }

  private static func globalRequest(_ words: [String], topic: String) throws -> ControlRequest {
    switch (words.first, words.count) {
    case ("list", 1): .readGlobalSettings(key: nil)
    case ("get", 2): .readGlobalSettings(key: words[1])
    case ("set", 3): .writeGlobalSetting(key: words[1], value: words[2])
    default: throw UsageError("config global needs: list, get KEY or set KEY VALUE", topic: topic)
    }
  }

  private static func projectRequest(
    _ words: [String],
    project: String,
    topic: String,
  ) throws -> ControlRequest {
    switch (words.first, words.count) {
    case ("list", 1): .readProjectSettings(project: project, key: nil)
    case ("get", 2): .readProjectSettings(project: project, key: words[1])
    case ("set", 3): .writeProjectSetting(project: project, key: words[1], value: words[2])

    default:
      throw UsageError("config project needs: list, get KEY or set KEY VALUE", topic: topic)
    }
  }
}
