import Foundation
import MultishellCore

extension Helper {
  /// What `debug git` prints unless told.
  private static let gitRunCount = 20

  static func runDebug(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.debug.rawValue
    let rest = arguments.dropFirst()
    switch (arguments.first, rest.first, rest.count) {
    case ("tools", "on", 1):
      return try ask(.setDebugTools(enabled: true), environment: environment)

    case ("tools", "off", 1):
      return try ask(.setDebugTools(enabled: false), environment: environment)

    case ("info", "show", 1): return try ask(.setDebugInfo(shown: true), environment: environment)
    case ("info", "hide", 1): return try ask(.setDebugInfo(shown: false), environment: environment)
    case ("samples", _, _): return try runDebugSamples(rest, environment: environment)
    case ("memory", nil, 0): return try ask(.debugMemory, environment: environment)
    case ("notifications", nil, 0): return try ask(.debugNotifications, environment: environment)

    case ("git", _, _):
      let options = try CommandOptions(rest, valued: ["last"], topic: topic)
      let last = try options.count("last") ?? gitRunCount
      return try ask(.debugGitRuns(last: last), environment: environment)

    case ("mark", let name?, 1):
      return try ask(.markDebugSample(name: name), environment: environment)

    case ("report", _, _): return try runDebugReport(rest, environment: environment)
    case ("screenshot", _, _): return try runDebugScreenshot(rest, environment: environment)
    case ("log", _, _): return try runDebugLog(rest, environment: environment)
    case ("services", _, _): return try runDebugServices(rest, environment: environment)

    default:
      throw UsageError(
        "debug needs one of: tools, info, samples, memory, notifications, git, mark, report, "
          + "screenshot, log, services",
        topic: topic,
      )
    }
  }

  /// A state for the pane as a hook would report it, through the app's own
  /// handling of one; prints the pane as it then is.
  private static func runDebugReport(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = ControlCommand.debug.rawValue
    let (words, optionWords) = positionals(arguments)
    guard words.count == 2, let state = SessionState(rawValue: words[1]) else {
      throw UsageError("debug report needs PANE_ID and one of: \(stateList)", topic: topic)
    }
    let options = try CommandOptions(optionWords, valued: ["agent", "message"], topic: topic)
    let report = SessionStateReport(
      state: state,
      sessionID: try tabOrPaneID(words[0], topic: topic),
      message: options["message"],
      agentID: options["agent"],
    )
    return try ask(.reportPaneState(report), environment: environment)
  }
}
