import Foundation
import MultishellCore

extension Helper {
  /// A person typed this line, so a missing agent is refused, not guessed.
  private static func requiredIntegration(_ options: CommandOptions) throws -> AgentHookIntegration
  {
    guard let id = options["agent"] else { throw UsageError("--agent is required") }
    guard let integration = AgentHookCatalogue.integration(id) else {
      throw UsageError(
        "no hooks for \(id); known agents: \(knownAgentList)")
    }
    return integration
  }

  static func installAgentHooks(_ arguments: ArraySlice<String>) throws {
    let options = try CommandOptions(arguments, valued: ["agent"], flags: ["print"])
    let integration = try requiredIntegration(options)
    if options.has("print") {
      print(integration.snippet(), terminator: "")
    } else {
      try integration.install()
      print("\(integration.name) hooks added to \(integration.file.path)")
    }
  }

  static func removeAgentHooks(_ arguments: ArraySlice<String>) throws {
    let integration = try requiredIntegration(CommandOptions(arguments, valued: ["agent"]))
    try integration.remove()
    print("\(integration.name) hooks removed from \(integration.file.path)")
  }
}
