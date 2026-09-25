import Foundation
import MultishellCore

extension Helper {
  private static let stateOptionNames: Set<String> = [
    "session", "cwd", "pid", "message", "agent", "subagent", "subagent-phase", "subagent-type",
    "new-turn", "shell",
  ]

  static func reportState(_ arguments: [String], environment: [String: String]) throws -> Int32 {
    guard let name = arguments.first, let state = SessionState(rawValue: name) else {
      throw UsageError(
        "state needs one of: \(SessionState.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    let options = try CommandOptions(arguments.dropFirst(), valued: stateOptionNames)
    let report = SessionStateReport(
      state: state,
      sessionID: sessionID(from: options["session"] ?? environment[SessionEnvironment.sessionKey]),
      cwd: options["cwd"] ?? environment[SessionEnvironment.workingDirectoryKey]
        ?? FileManager.default.currentDirectoryPath,
      pid: options.int32("pid") ?? reportingProcess(environment),
      message: options["message"],
      agent: options["agent"],
      isShell: options["shell"] == "true" ? true : nil,
      subagent: try subagent(options),
      startsTurn: options["new-turn"] == "true" ? true : nil)
    do {
      try send(report, environment: environment)
      return 0
    } catch {
      printError("could not reach Multishell: \(error)")
      return 1
    }
  }

  private static func subagent(_ options: CommandOptions) throws -> SubagentReport? {
    guard let id = options["subagent"] else {
      if let orphan = ["subagent-phase", "subagent-type"].first(where: { options[$0] != nil }) {
        throw UsageError("--\(orphan) needs --subagent")
      }
      return nil
    }
    guard let phase = options["subagent-phase"].flatMap(SubagentReport.Phase.init(rawValue:))
    else {
      throw UsageError(
        "--subagent needs --subagent-phase, one of: "
          + SubagentReport.Phase.allCases.map(\.rawValue).joined(separator: ", "))
    }
    return SubagentReport(id: id, type: options["subagent-type"], phase: phase)
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
      sessionID: sessionID(from: environment[SessionEnvironment.sessionKey]),
      cwd: environment[SessionEnvironment.workingDirectoryKey],
      pid: pid,
      duration: duration,
      command: command,
      isShell: true)
    // A shell hook must never make the prompt print an error.
    try? send(report, environment: environment)
  }
}
