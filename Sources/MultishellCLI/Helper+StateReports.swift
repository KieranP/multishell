import Foundation
import MultishellCore

extension Helper {
  private static let stateOptionNames: Set<String> = [
    "session", "cwd", "pid", "message", "agent", "subagent", "subagent-phase", "subagent-type",
    "new-turn", "shell", "resumes", "subagent-wakes", "out",
  ]

  static func reportState(
    _ arguments: ArraySlice<String>, environment: [String: String]
  ) throws -> Int32 {
    guard let name = arguments.first, let state = SessionState(rawValue: name) else {
      throw UsageError(
        "state needs one of: \(SessionState.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    let options = try CommandOptions(arguments.dropFirst(), valued: stateOptionNames)
    let report = SessionStateReport(
      state: state,
      sessionID: sessionID(
        from: options["session"] ?? environment[SessionEnvironment.sessionVariable]),
      workingDirectory: options["cwd"] ?? worktreePath(in: environment)
        ?? FileManager.default.currentDirectoryPath,
      pid: options.int32("pid") ?? reportingPID(environment),
      message: options["message"],
      agentID: options["agent"],
      isFromShellIntegration: options.onlyIfTrue("shell"),
      worker: try workerReport(from: options),
      startsTurn: options.onlyIfTrue("new-turn"),
      resumesAfterWorkers: options.onlyIfTrue("resumes"),
      workersOut: options["out"].map { list in
        list.split(separator: ",").map { WorkerReport(id: String($0), phase: .working) }
      })
    do {
      try send(report, environment: environment)
      return 0
    } catch {
      printError("could not reach Multishell: \(error)")
      return 1
    }
  }

  private static func workerReport(from options: CommandOptions) throws -> WorkerReport? {
    guard let id = options["subagent"] else {
      let orphan = ["subagent-phase", "subagent-type", "subagent-wakes"].first {
        options[$0] != nil
      }
      if let orphan {
        throw UsageError("--\(orphan) needs --subagent")
      }
      return nil
    }
    guard let phase = options["subagent-phase"].flatMap(WorkerReport.Phase.init(rawValue:))
    else {
      throw UsageError(
        "--subagent needs --subagent-phase, one of: "
          + WorkerReport.Phase.allCases.map(\.rawValue).joined(separator: ", "))
    }
    return WorkerReport(
      id: id, type: options["subagent-type"], phase: phase,
      wakesAgent: options.onlyIfFalse("subagent-wakes"))
  }
}
