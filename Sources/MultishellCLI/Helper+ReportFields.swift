import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// A report's pane, as `--session` or the app's environment names it. Not
  /// a UUID is no pane, the report still reaching the worktree by its `workingDirectory`.
  static func sessionID(from text: String?) -> UUID? {
    text.flatMap { UUID(uuidString: $0) }
  }

  static func sessionID(in environment: [String: String]) -> UUID? {
    sessionID(from: environment[SessionEnvironment.sessionVariable])
  }

  static func worktreePath(in environment: [String: String]) -> String? {
    environment[SessionEnvironment.worktreePathVariable]
  }

  /// The program that ran this, the walk stopping short of the app itself:
  /// from a prompt in one of its tabs that leaves the shell, whose exit clears.
  static func reportingPID(_ environment: [String: String]) -> Int32 {
    ProcessAncestry.reportingPID(
      stoppingAt: environment[SessionEnvironment.appPIDVariable].flatMap { Int32($0) })
  }
}
