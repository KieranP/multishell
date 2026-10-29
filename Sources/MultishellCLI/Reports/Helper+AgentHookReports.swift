import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// Nothing this prints or returns may disturb the agent: exit 0, no
  /// stdout, and an event that stands for nothing costs one silent process.
  static func reportAgentHook(
    _ id: String?,
    event: String?,
    environment: [String: String],
    input: FileHandle,
  ) {
    let payloadJSON = input.readDataToEndOfFile()
    guard let integration = id.flatMap(AgentHookCatalogue.integration),
      let payload = integration.payload(json: payloadJSON, eventName: event),
      integration.asksFor(payload)
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

  /// Which agent a hook line names; one naming none reports nothing, as
  /// every line written names one. Read by hand, as a hook must never fail.
  static func agentID(in arguments: [String]) -> String? {
    value(of: "--agent", in: arguments)
  }

  /// The event a hook line names, for an agent whose payload does not.
  static func hookEventName(in arguments: [String]) -> String? {
    value(of: "--event", in: arguments)
  }

  private static func value(of flag: String, in arguments: [String]) -> String? {
    guard let flagIndex = arguments.firstIndex(of: flag), flagIndex + 1 < arguments.count
    else {
      return nil
    }
    return arguments[flagIndex + 1]
  }
}
