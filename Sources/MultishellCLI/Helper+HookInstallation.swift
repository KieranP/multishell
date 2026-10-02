import Foundation
import MultishellCore

extension Helper {
  /// A person typed this line, so a missing agent is refused, not guessed.
  static func requiredIntegration(_ options: CommandOptions) throws -> AgentHookIntegration {
    guard let id = options["agent"] else { throw UsageError("--agent is required") }
    guard let integration = AgentHookCatalogue.integration(id) else {
      throw UsageError(
        "no hooks for \(id); known agents: \(knownAgentList)")
    }
    return integration
  }

  static func installHooks(
    _ integration: AgentHookIntegration, print shouldPrint: Bool
  ) throws
    -> Int32
  {
    if shouldPrint {
      print(integration.snippet(), terminator: "")
      return 0
    }
    try integration.install()
    print("\(integration.name) hooks added to \(integration.file.path)")
    return 0
  }

  static func removeHooks(_ integration: AgentHookIntegration) throws -> Int32 {
    try integration.remove()
    print("\(integration.name) hooks removed from \(integration.file.path)")
    return 0
  }
}
