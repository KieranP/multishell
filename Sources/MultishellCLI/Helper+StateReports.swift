import Foundation
import MultishellCore

extension Helper {
  private static let stateOptionNames: Set<String> = [
    "session", "cwd", "pid", "message", "agent", "subagent", "subagent-phase", "subagent-type",
    "new-turn", "shell", "resumes", "subagent-wakes", "out",
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
      cwd: options["cwd"] ?? environment[SessionEnvironment.worktreeKey]
        ?? FileManager.default.currentDirectoryPath,
      pid: options.int32("pid") ?? reportingPID(environment),
      message: options["message"],
      agentID: options["agent"],
      isFromShellIntegration: options.onlyIfTrue("shell"),
      subagent: try subagentReport(from: options),
      startsTurn: options.onlyIfTrue("new-turn"),
      resumesAfterWorkers: options.onlyIfTrue("resumes"),
      workersOut: options["out"].map { list in
        list.split(separator: ",").map { SubagentReport(id: String($0), phase: .working) }
      })
    do {
      try send(report, environment: environment)
      return 0
    } catch {
      printError("could not reach Multishell: \(error)")
      return 1
    }
  }

  private static func subagentReport(from options: CommandOptions) throws -> SubagentReport? {
    guard let id = options["subagent"] else {
      let orphan = ["subagent-phase", "subagent-type", "subagent-wakes"].first {
        options[$0] != nil
      }
      if let orphan {
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
    return SubagentReport(
      id: id, type: options["subagent-type"], phase: phase,
      wakesAgent: options.onlyIfFalse("subagent-wakes"))
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
      cwd: environment[SessionEnvironment.worktreeKey],
      pid: pid,
      duration: duration,
      command: command,
      isFromShellIntegration: true)
    // A shell hook must never make the prompt print an error.
    try? send(report, environment: environment)
  }
}
