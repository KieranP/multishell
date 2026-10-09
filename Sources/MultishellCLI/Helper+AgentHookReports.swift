import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// Nothing this prints or returns may disturb the agent: exit 0, no
  /// stdout, and an event that stands for nothing costs one silent process.
  static func reportAgentHook(
    _ id: String,
    environment: [String: String],
    input: FileHandle,
  ) {
    let payloadJSON = input.readDataToEndOfFile()
    guard let integration = AgentHookCatalogue.integration(id),
      let payload = AgentHookPayload(json: payloadJSON), integration.asksFor(payload)
    else { return }
    let pid = reportingPID(in: environment)
    guard
      let report = integration.report(
        for: payload,
        sessionID: sessionID(in: environment),
        workingDirectory: worktreePath(in: environment),
        pid: pid,
        findBackgroundShells: { backgroundShells(of: pid, marker: $0) },
      )
    else { return }
    try? send(report, environment: environment)
  }

  /// A Stop comes with no tool running, so any tool shell still alive under
  /// the agent is one it backgrounded. `nil` for none, keeping the line short.
  private static func backgroundShells(of agentPID: Int32, marker: String) -> [Int32]? {
    let shells = KernelProcessTable.children(of: agentPID, whoseArgumentsContain: marker)
    return shells.isEmpty ? nil : shells
  }

  /// Which agent a hook line names, Claude Code when it names none. Read by
  /// hand, since a hook must never fail over an argument.
  static func agentID(in arguments: [String]) -> String {
    guard let flag = arguments.firstIndex(of: "--agent"), flag + 1 < arguments.count else {
      return AgentCatalogue.claudeID
    }
    return arguments[flag + 1]
  }
}
