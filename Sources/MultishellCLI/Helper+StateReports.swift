import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  static func state(_ arguments: [String], environment: [String: String]) throws -> Int32 {
    guard let name = arguments.first, let state = SessionState(rawValue: name) else {
      throw UsageError(
        "state needs one of: \(SessionState.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    let options = try CommandOptions(arguments.dropFirst())
    let report = SessionStateReport(
      state: state,
      sessionID: sessionID(from: options["session"] ?? environment[SessionEnvironment.sessionKey]),
      cwd: options["cwd"] ?? environment[SessionEnvironment.worktreeKey]
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
      fail("could not reach Multishell: \(error)")
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

  /// A report's pane, as `--session` or the app's environment names it. Not
  /// a UUID is no pane, the report still reaching the worktree by its `cwd`.
  static func sessionID(from text: String?) -> UUID? {
    text.flatMap { UUID(uuidString: $0) }
  }

  /// A state with no message, for the shell hooks. The pid, when given, is
  /// the shell's, a command's not being known in a preexec hook.
  static func reportShellState(
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
      isShell: true)
    // A shell hook must never make the prompt print an error.
    try? send(report, environment: environment)
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
