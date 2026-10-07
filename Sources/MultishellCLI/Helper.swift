import Foundation
import MultishellCore

/// The `multishell` command: reports a session's state over the socket and
/// installs the agent hooks. Silent from a hook, loud from the terminal.
enum Helper {
  static func run(
    _ arguments: [String], environment: [String: String], standardInput: FileHandle
  )
    -> Int32
  {
    do {
      switch arguments.first {
      case "state":
        return try reportState(arguments.dropFirst(), environment: environment)
      case "command-started":
        try reportCommandStarted(arguments.dropFirst(), environment: environment)
        return 0
      case "command-finished":
        try reportCommandFinished(arguments.dropFirst(), environment: environment)
        return 0
      case "relay":
        try relay(arguments.dropFirst(), environment: environment, input: standardInput)
        return 0
      case AgentHookCatalogue.subcommand, AgentHookCatalogue.legacySubcommand:
        reportAgentHook(agentID(in: arguments), environment: environment, input: standardInput)
        return 0
      case "install-agent-hooks":
        try installAgentHooks(arguments.dropFirst())
        return 0
      case "remove-agent-hooks":
        try removeAgentHooks(arguments.dropFirst())
        return 0
      case "--version", "version":
        print("multishell helper, protocol version \(SessionStateReport.protocolVersion)")
        return 0
      case nil, "help", "--help", "-h":
        FileHandle.standardError.write(Data(usage.utf8))
        return arguments.isEmpty ? 2 : 0
      default:
        throw UsageError("unknown command \(arguments[0])")
      }
    } catch let error as UsageError {
      printError("\(error.message)\n\n\(usage)")
      return 2
    } catch {
      printError("\(error)")
      return 1
    }
  }

  static func printError(_ message: String) {
    FileHandle.standardError.write(Data("multishell: \(message)\n".utf8))
  }
}
