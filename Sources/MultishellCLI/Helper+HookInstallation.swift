import Foundation
import MultishellCore

extension Helper {
  static let installHooksName = "install-agent-hooks"
  static let removeHooksName = "remove-agent-hooks"

  /// A person typed this line, so a missing agent is refused, not guessed.
  private static func requiredIntegration(
    _ options: CommandOptions,
    topic: String,
  ) throws -> AgentHookIntegration {
    guard let id = options["agent"] else {
      throw UsageError("--agent is required", topic: topic)
    }
    guard let integration = AgentHookCatalogue.integration(id) else {
      throw UsageError("no hooks for \(id); known agents: \(knownAgentList)", topic: topic)
    }
    return integration
  }

  static func installAgentHooks(_ arguments: ArraySlice<String>) throws {
    let options = try CommandOptions(
      arguments,
      valued: ["agent"],
      flags: ["print"],
      topic: installHooksName,
    )
    let integration = try requiredIntegration(options, topic: installHooksName)
    if options.has("print") {
      // Raw, not wrapped in JSON, so it redirects into the agent's own file.
      print(integration.snippet(), terminator: "")
    } else {
      try integration.install()
      try printJSON(["agent": integration.id, "file": integration.file.path])
    }
  }

  static func removeAgentHooks(_ arguments: ArraySlice<String>) throws {
    let integration = try requiredIntegration(
      CommandOptions(arguments, valued: ["agent"], topic: removeHooksName),
      topic: removeHooksName,
    )
    try integration.remove()
    try printJSON(["agent": integration.id, "file": integration.file.path])
  }
}
