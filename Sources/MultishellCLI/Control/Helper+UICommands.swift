import Foundation
import MultishellCore

extension Helper {
  static func runUI(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.userInterface.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    if arguments.first == "switcher" {
      return try ask(
        .quickSwitcher(try switcherOrder(words, optionWords)),
        environment: environment,
      )
    }
    try noOptions(optionWords, topic: topic)
    switch (arguments.first, words.count) {
    case ("show", 1...2):
      let view = try controlView(words[0])
      if view == .services {
        let worktree = try words.dropFirst().first.map { try worktreeID($0, topic: topic) }
        return try ask(.showServices(worktree: worktree), environment: environment)
      }
      guard words.count == 1 || view == .projectSettings else {
        throw UsageError(
          "only project-settings takes a PROJECT_ID, and services a WORKTREE_ID",
          topic: topic,
        )
      }
      let project = words.count == 2 ? try projectID(words[1], topic: topic) : nil
      return try ask(.showView(view, project: project), environment: environment)

    case ("hide", 1):
      return try ask(.hideView(try controlView(words[0])), environment: environment)

    case ("filter", 0...1):
      return try ask(.filterSidebar(text: words.first ?? ""), environment: environment)

    case ("dismiss", 0):
      return try ask(.dismissPresentation, environment: environment)

    case ("menu", 0):
      return try ask(.listMenuItems, environment: environment)

    // One word as `View > Find…`, or each title a word of its own.
    case ("menu", 1...):
      let path =
        words.count == 1
        ? words[0].components(separatedBy: " > ") : words
      return try ask(.performMenuItem(path: path), environment: environment)

    default:
      throw UsageError(
        "ui needs: show VIEW, hide VIEW, filter [TEXT], dismiss, menu or switcher",
        topic: topic,
      )
    }
  }

  /// `[TEXT] [--scope SCOPE] [--next | --previous] [--choose]`.
  private static func switcherOrder(
    _ words: [String],
    _ optionWords: ArraySlice<String>,
  ) throws -> QuickSwitcherOrder {
    let topic = ControlCommand.userInterface.rawValue
    guard words.count <= 1 else {
      throw UsageError("ui switcher takes one TEXT; quote one with spaces", topic: topic)
    }
    let options = try CommandOptions(
      optionWords,
      valued: ["scope"],
      flags: ["next", "previous", "choose"],
      topic: topic,
    )
    return QuickSwitcherOrder(
      scope: options["scope"],
      text: words.first,
      step: try direction(in: options, command: "ui switcher", topic: topic),
      choosesSelected: options.has("choose"),
    )
  }

  private static func controlView(_ word: String) throws -> ControlView {
    guard let view = ControlView(rawValue: word) else {
      let viewList = ControlView.allCases.map(\.rawValue).joined(separator: ", ")
      throw UsageError(
        "no view \(word); the views are \(viewList)",
        topic: ControlCommand.userInterface.rawValue,
      )
    }
    return view
  }
}
