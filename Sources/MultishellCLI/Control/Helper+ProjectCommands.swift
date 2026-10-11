import Foundation
import MultishellCore

extension Helper {
  static func runProjects(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = "projects"
    let (words, options) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 0):
      try noOptions(options, topic: topic)
      return try ask(.listProjects, environment: environment)

    case ("add", 0...1):
      try noOptions(options, topic: topic)
      return try ask(.addProject(path: absolutePath(words.first)), environment: environment)

    case ("remove", 1):
      let force = try isForced(options, topic: topic)
      return try ask(
        .removeProject(id: try projectID(words[0], topic: topic), force: force),
        environment: environment,
      )

    default:
      throw UsageError("projects needs: list, add [PATH] or remove PROJECT_ID", topic: topic)
    }
  }
}
