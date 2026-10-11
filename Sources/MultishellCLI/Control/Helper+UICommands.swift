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
    let (words, options) = positionals(arguments.dropFirst())
    try noOptions(options, topic: topic)
    switch (arguments.first, words.count) {
    case ("show", 1...2):
      let view = try controlView(words[0])
      guard words.count == 1 || view == .projectSettings else {
        throw UsageError("only project-settings takes a PROJECT_ID", topic: topic)
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
        "ui needs: show VIEW, hide VIEW, filter [TEXT], dismiss or menu",
        topic: topic,
      )
    }
  }

  private static func controlView(_ word: String) throws -> ControlView {
    guard let view = ControlView(rawValue: word) else {
      let views = ControlView.allCases.map(\.rawValue).joined(separator: ", ")
      throw UsageError(
        "no view \(word); the views are \(views)",
        topic: ControlCommand.userInterface.rawValue,
      )
    }
    return view
  }
}
