import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// Nothing this prints or returns may disturb the agent: exit 0, no
  /// stdout, and an event that stands for nothing costs one silent process.
  static func agentHook(
    _ id: String, environment: [String: String], input: FileHandle
  ) {
    let data = input.readDataToEndOfFile()
    guard let integration = AgentHookCatalogue.integration(for: id),
      let payload = AgentHookPayload(json: data), integration.event(for: payload) != nil
    else { return }
    let pid = reportingProcess(environment)
    guard
      let report = integration.report(
        for: payload,
        session: sessionID(from: environment[SessionEnvironment.sessionKey]),
        cwd: environment[SessionEnvironment.worktreeKey], pid: pid,
        backgroundShells: { backgroundShells(of: pid, marker: $0) })
    else { return }
    try? send(report, environment: environment)
  }

  /// A Stop comes with no tool running, so any tool shell still alive under
  /// the agent is one it backgrounded. `nil` for none, keeping the line short.
  private static func backgroundShells(of agentPID: Int32, marker: String) -> [Int32]? {
    let shells = ProcessAncestry.children(of: agentPID, whoseArgumentsContain: marker)
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

  /// A person typed this line, so a missing agent is refused, not guessed.
  static func requiredIntegration(_ options: CommandOptions) throws -> AgentHookIntegration {
    guard let id = options["agent"] else { throw UsageError("--agent is required") }
    guard let integration = AgentHookCatalogue.integration(for: id) else {
      throw UsageError(
        "no hooks for \(id); known agents: \(knownAgents)")
    }
    return integration
  }

  static func installHooks(
    _ integration: AgentHookIntegration, print shouldPrint: Bool
  )
    -> Int32
  {
    if shouldPrint {
      print(integration.snippet(), terminator: "")
      return 0
    }
    do {
      try integration.install()
      print("\(integration.name) hooks added to \(integration.file.path)")
      return 0
    } catch {
      fail("\(error)")
      return 1
    }
  }

  static func removeHooks(_ integration: AgentHookIntegration) -> Int32 {
    do {
      try integration.remove()
      print("\(integration.name) hooks removed from \(integration.file.path)")
      return 0
    } catch {
      fail("\(error)")
      return 1
    }
  }
}
