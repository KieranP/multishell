import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// Names another socket, for the tests; a debug build's alone, so nothing
  /// left in a release shell's environment turns its helper on another app.
  static let controlSocketVariable = "MULTISHELL_CONTROL_SOCKET"
  /// Long for a request the app answers on the spot; a create or a removal
  /// gets none, its hooks having no limit unless the user set one.
  static let answerTimeout: Duration = .seconds(30)

  /// This build's own app, never the pane's `MULTISHELL_SOCKET`: a debug
  /// helper run in a release app's tab drives the debug app.
  static func controlSocket(in environment: [String: String]) -> URL {
    #if DEBUG
      if let path = environment[controlSocketVariable] { return URL(fileURLWithPath: path) }
    #endif
    return Paths.socketFile
  }

  /// The app's answer, `nil` where it closed without one, as an older app
  /// does and as one quitting may.
  static func reply(
    to request: ControlRequest,
    environment: [String: String],
    timeout: Duration? = answerTimeout,
  ) throws -> ControlReply? {
    let line = try request.encodedLine()
    guard line.utf8.count <= UnixSocketServer.maximumLineLength else {
      throw ControlRequestTooLong(byteCount: line.utf8.count)
    }
    let answer = try UnixSocketClient.request(
      line,
      to: controlSocket(in: environment),
      timeout: timeout,
    )
    return ControlReply.parse(answer)
  }

  /// What the app answered: its output, `nil` for a plain done. A refusal,
  /// or no answer at all, is thrown in words.
  static func output(
    of request: ControlRequest,
    environment: [String: String],
    timeout: Duration? = answerTimeout,
  ) throws -> String? {
    let answer: ControlReply?
    do {
      answer = try reply(to: request, environment: environment, timeout: timeout)
    } catch let failure as SocketFailure {
      throw ControlUnanswered.unreachable(failure)
    }
    guard let answer else { throw ControlUnanswered.silent }
    if let refusal = answer.refusal { throw ControlRefused(refusal: refusal) }
    return answer.output
  }

  /// Prints what the app answered.
  static func ask(
    _ request: ControlRequest,
    environment: [String: String],
    timeout: Duration? = answerTimeout,
  ) throws -> Int32 {
    if let output = try output(of: request, environment: environment, timeout: timeout) {
      print(output)
    }
    return 0
  }
}
