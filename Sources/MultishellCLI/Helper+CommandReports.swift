import Foundation
import MultishellCore

extension Helper {
  static func reportCommandStarted(
    _ arguments: ArraySlice<String>, environment: [String: String]
  ) throws {
    let options = try CommandOptions(arguments, valued: ["pid", "command"])
    reportCommandStarted(
      environment: environment, shellPID: options.int32("pid"), command: options["command"])
  }

  static func reportCommandFinished(
    _ arguments: ArraySlice<String>, environment: [String: String]
  ) throws {
    let options = try CommandOptions(arguments, valued: ["exit", "duration"])
    reportCommandFinished(
      environment: environment, exitCode: options.int32("exit"),
      duration: options.double("duration"))
  }

  /// For a preexec hook, from the command line or a relayed line alike. The
  /// pid is the shell's, a command's not being known there.
  static func reportCommandStarted(
    environment: [String: String], shellPID: Int32?, command: String?
  ) {
    reportShellState(.running, environment: environment, pid: shellPID, command: command)
  }

  /// For a precmd hook, from the command line or a relayed line alike.
  static func reportCommandFinished(
    environment: [String: String], exitCode: Int32?, duration: Double?
  ) {
    reportShellState(.finished(exitCode: exitCode), environment: environment, duration: duration)
  }

  /// A state with no message, sent as the injected shell integration.
  private static func reportShellState(
    _ state: SessionState, environment: [String: String], pid: Int32? = nil,
    duration: Double? = nil, command: String? = nil
  ) {
    let report = SessionStateReport(
      state: state,
      sessionID: sessionID(in: environment),
      workingDirectory: worktreePath(in: environment),
      pid: pid,
      duration: duration,
      command: command,
      isFromShellIntegration: true)
    // A shell hook must never make the prompt print an error.
    try? send(report, environment: environment)
  }
}
