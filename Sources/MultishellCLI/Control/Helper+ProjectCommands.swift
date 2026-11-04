import Foundation
import MultishellCore

extension Helper {
  static func runProjects(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.projects.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 0):
      try noOptions(optionWords, topic: topic)
      return try ask(.listProjects, environment: environment)

    case ("add", 0...1):
      try noOptions(optionWords, topic: topic)
      return try ask(.addProject(path: absolutePath(words.first)), environment: environment)

    case ("remove", 1):
      let force = try isForced(optionWords, topic: topic)
      return try ask(
        .removeProject(id: try projectID(words[0], topic: topic), force: force),
        environment: environment,
      )

    case ("expand", 1), ("collapse", 1), ("expand-hidden", 1), ("collapse-hidden", 1):
      try noOptions(optionWords, topic: topic)
      let id = try projectID(words[0], topic: topic)
      let expanded = arguments.first?.hasPrefix("expand") == true
      let request: ControlRequest =
        arguments.first?.hasSuffix("-hidden") == true
        ? .setHiddenSectionExpanded(id: id, expanded: expanded)
        : .setProjectExpanded(id: id, expanded: expanded)
      return try ask(request, environment: environment)

    case ("move", 1):
      let usage = "projects move needs one of --before PROJECT_ID or --after PROJECT_ID"
      let options = try CommandOptions(optionWords, valued: ["before", "after"], topic: topic)
      guard let (placement, anchor) = try placement(in: options, usage: usage, topic: topic)
      else { throw UsageError(usage, topic: topic) }
      let request = ControlRequest.moveProject(
        id: try projectID(words[0], topic: topic),
        placement: placement == .before ? .above : .below,
        anchor: try projectID(anchor, topic: topic),
      )
      return try ask(request, environment: environment)

    case ("refresh", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .refreshProject(id: try projectID(words[0], topic: topic)),
        environment: environment,
        timeout: nil,
      )

    case ("fetch", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .fetchProject(id: try projectID(words[0], topic: topic)),
        environment: environment,
        timeout: nil,
      )

    default:
      throw UsageError(
        "projects needs: list, add [PATH], remove, expand, collapse, expand-hidden, "
          + "collapse-hidden, move, refresh or fetch",
        topic: topic,
      )
    }
  }
}
