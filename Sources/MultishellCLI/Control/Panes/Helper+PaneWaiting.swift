import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  private static let paneWaitTimeout: Duration = .seconds(30)
  private static let paneWaitInterval: Duration = .milliseconds(250)
  /// What `--state` takes beyond the states: the pane showing no dot.
  private static let noState = "none"

  /// Polled from here, not held open in the app: each look is a request it
  /// answers at once, so a long wait costs the app nothing between looks.
  static func waitForPane(
    _ id: UUID,
    _ optionWords: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = ControlCommand.panes.rawValue
    let options = try CommandOptions(
      optionWords,
      valued: ["state", "text", "timeout"],
      flags: ["scrollback"],
      topic: topic,
    )
    let timeout =
      try options.seconds("timeout") ?? paneWaitTimeout
    let look: (Duration) throws -> String?
    switch (options["state"], options["text"]) {
    case (let state?, nil):
      guard !options.has("scrollback") else {
        throw UsageError("--scrollback goes with --text", topic: topic)
      }
      look = try stateLook(for: id, reaching: state, environment: environment)

    case (nil, let pattern?):
      look = try textLook(
        for: id,
        matching: pattern,
        includingScrollback: options.has("scrollback"),
        environment: environment,
      )

    default:
      throw UsageError("panes wait needs one of --state STATE or --text PATTERN", topic: topic)
    }
    let found = try poll(every: paneWaitInterval, for: timeout) { remaining in
      try notYetWhereCutShort { try look(remaining) }
    }
    guard let found else {
      printError(
        "pane \(id) did not get there within \(String(format: "%g", timeout.inSeconds)) seconds"
      )
      return 1
    }
    print(found)
    return 0
  }

  /// Finds the pane's details once its dot is `state`.
  private static func stateLook(
    for id: UUID,
    reaching state: String,
    environment: [String: String],
  ) throws -> (Duration) throws -> String? {
    guard state == noState || SessionState(rawValue: state) != nil else {
      throw UsageError(
        "--state takes one of: \(noState), \(stateList)",
        topic: ControlCommand.panes.rawValue,
      )
    }
    // The app keeps no idle state: an idle report takes the dot away.
    let wanted = state == noState || state == SessionState.idle.rawValue ? nil : state
    return { remaining in
      let pane = try describedPane(id, environment: environment, timeout: remaining)
      return pane.fields["state"] as? String == wanted ? pane.text : nil
    }
  }

  /// Finds the newest line `pattern` matches, as JSON beside the pane. The
  /// scrollback is read once: the app reads it on its main thread, megabytes a look.
  private static func textLook(
    for id: UUID,
    matching pattern: String,
    includingScrollback: Bool,
    environment: [String: String],
  ) throws -> (Duration) throws -> String? {
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
      throw UsageError(
        "--text is no pattern NSRegularExpression reads: \(pattern)",
        topic: ControlCommand.panes.rawValue,
      )
    }
    var readsScrollback = includingScrollback
    return { remaining in
      let text = try paneText(
        of: id,
        includingScrollback: readsScrollback,
        lastLines: nil,
        environment: environment,
        timeout: remaining,
      )
      readsScrollback = false
      let line = text.components(separatedBy: "\n").last { line in
        expression.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
      }
      return try line.map { try jsonText(["pane": id.uuidString, "line": $0]) }
    }
  }
}
