import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// A report's pane, as `--session` or the app's environment names it. Not
  /// a UUID is no pane, the report still reaching the worktree by its `cwd`.
  static func sessionID(from text: String?) -> UUID? {
    text.flatMap { UUID(uuidString: $0) }
  }

  /// The program that ran this, the walk stopping short of the app itself:
  /// from a prompt in one of its tabs that leaves the shell, whose exit clears.
  static func reportingProcess(_ environment: [String: String]) -> Int32 {
    ProcessAncestry.reportingProcess(
      stoppingAt: environment[SessionEnvironment.appPIDKey].flatMap { Int32($0) })
  }

  static func send(_ report: SessionStateReport, environment: [String: String]) throws {
    let socket =
      environment[SessionEnvironment.socketKey].map { URL(fileURLWithPath: $0) }
      ?? Paths.socketFile
    try UnixSocketClient.send(try report.encodedLine(), to: socket)
  }
}
