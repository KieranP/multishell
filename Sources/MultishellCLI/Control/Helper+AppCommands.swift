import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// How long `open` waits for a launch to answer and `quit` for it to go.
  private static let launchTimeout: Duration = .seconds(30)
  private static let pollInterval: Duration = .milliseconds(200)
  /// Names a stand-in for `/usr/bin/open`, for the tests, which may not launch
  /// an app; a debug build's alone, as the socket's is.
  static let openerVariable = "MULTISHELL_OPENER"

  /// The bundle this helper ships in, through any link to it.
  static var ownApp: URL? {
    Bundle.main.executableURL?.enclosingAppBundle
  }

  private static func opener(in environment: [String: String]) -> URL {
    #if DEBUG
      if let path = environment[openerVariable] { return URL(fileURLWithPath: path) }
    #endif
    return URL(fileURLWithPath: "/usr/bin/open")
  }

  /// This build's own app, launched or brought forward, returning once it answers.
  static func runOpen(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    guard arguments.isEmpty else {
      throw UsageError("open takes no arguments", topic: ControlCommand.open.rawValue)
    }
    guard let app = ownApp else {
      printError("this helper is in no app bundle, so there is no app to open")
      return 1
    }
    let launch = try Process.run(opener(in: environment), arguments: [app.path])
    launch.waitUntilExit()
    guard launch.terminationStatus == 0 else {
      printError("could not open \(app.path)")
      return 1
    }
    let answered =
      poll(every: pollInterval, for: launchTimeout) { remaining in
        try? reply(to: .info, environment: environment, timeout: remaining)
      } != nil
    guard answered else {
      printError(
        "\(app.path) opened but did not answer within \(launchTimeout.components.seconds) seconds"
      )
      return 1
    }
    return 0
  }

  /// Returns once the socket is gone, the answer itself racing the exit.
  static func runQuit(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
    waitingUpTo timeout: Duration = launchTimeout,
  ) throws
    -> Int32
  {
    let force = try isForced(arguments, topic: ControlCommand.quit.rawValue)
    let answer: ControlReply?
    do {
      answer = try reply(to: .quit(force: force), environment: environment)
    } catch is SocketFailure {
      return 0
    }
    if let refusal = answer?.refusal { throw ControlRefused(refusal: refusal) }
    let socket = controlSocket(in: environment)
    let gone = poll(every: pollInterval, for: timeout) { _ in
      (try? UnixSocketClient.send("", to: socket)) == nil ? true : nil
    }
    guard gone != nil else {
      // No answer is a quit racing its reply, unless the app stays up.
      if answer == nil { throw ControlUnanswered.silent }
      printError("Multishell is still running")
      return 1
    }
    return 0
  }

  static func runInfo(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    guard arguments.isEmpty else {
      throw UsageError("info takes no arguments", topic: ControlCommand.info.rawValue)
    }
    return try ask(.info, environment: environment)
  }
}
