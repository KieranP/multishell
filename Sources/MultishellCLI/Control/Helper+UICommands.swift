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
    if arguments.first == "show" {
      return try showView(words, optionWords, environment: environment)
    }
    try noOptions(optionWords, topic: topic)
    switch (arguments.first, words.count) {
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

  /// A view, a service page, or the settings window on one of its pages, asked
  /// for with its scope in one request, so a refused page moves nothing.
  private static func showView(
    _ words: [String],
    _ optionWords: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = ControlCommand.userInterface.rawValue
    guard !words.isEmpty else { throw UsageError("ui show needs a VIEW", topic: topic) }
    guard words.count <= 2 else {
      throw UsageError("ui show takes a VIEW and at most one ID", topic: topic)
    }
    if let page = ServicePage(rawValue: words[0]) {
      try noOptions(optionWords, topic: topic)
      let worktree = try words.dropFirst().first.map { try worktreeID($0, topic: topic) }
      return try ask(.showServicePage(page, worktree: worktree), environment: environment)
    }
    let view = try controlView(words[0], listingAlso: ServicePage.allCases.map(\.rawValue))
    guard words.count == 1 || view == .projectSettings else {
      throw UsageError(
        "only project-settings takes a PROJECT_ID, and pull-request and ci a WORKTREE_ID",
        topic: topic,
      )
    }
    let page = try CommandOptions(optionWords, valued: ["page"], topic: topic)["page"].map {
      word in try settingsPage(word, of: view)
    }
    let project = words.count == 2 ? try projectID(words[1], topic: topic) : nil
    guard let page else {
      return try ask(.showView(view, project: project), environment: environment)
    }
    return try ask(
      .showSettingsPage(page, inProject: view == .projectSettings, project: project),
      environment: environment,
    )
  }

  private static func settingsPage(
    _ word: String,
    of view: ControlView,
  ) throws
    -> ControlSettingsPage
  {
    let topic = ControlCommand.userInterface.rawValue
    guard view == .settings || view == .projectSettings else {
      throw UsageError("only settings and project-settings take --page", topic: topic)
    }
    guard let page = ControlSettingsPage(rawValue: word) else {
      let pages = ControlSettingsPage.allCases.map(\.rawValue).joined(separator: ", ")
      throw UsageError("no settings page \(word); the pages are \(pages)", topic: topic)
    }
    return page
  }

  /// `otherWords` are those the command takes beside a view, named with them.
  private static func controlView(
    _ word: String,
    listingAlso otherWords: [String] = [],
  ) throws -> ControlView {
    guard let view = ControlView(rawValue: word) else {
      let viewList = (ControlView.allCases.map(\.rawValue) + otherWords).joined(separator: ", ")
      throw UsageError(
        "no view \(word); the views are \(viewList)",
        topic: ControlCommand.userInterface.rawValue,
      )
    }
    return view
  }
}
