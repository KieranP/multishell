import Foundation
import MultishellCore

/// The `multishell` command: drives its own build's app, reports a session's
/// state, installs the agent hooks. Silent from a hook, loud from a terminal.
enum Helper {
  private static let helpFlags: Set<String> = ["--help", "-h"]
  static let helpCommands = helpFlags.union(["help"])
  /// Where a help flag is a subcommand's and never an option's value: `tabs -h`, `tabs open -h`.
  private static let subcommandWords = 2
  /// What hooks run, whose words are data: `--command -h` names a command.
  private static let reportCommands: Set<String> = [
    stateName, commandStartedName, commandFinishedName, relayName, AgentHookCatalogue.subcommand,
    AgentHookCatalogue.retiredSubcommand,
  ]

  static func run(
    _ arguments: [String],
    environment: [String: String],
    standardInput: FileHandle,
  )
    -> Int32
  {
    if let command = arguments.first, asksForHelp(arguments, within: subcommandWords) {
      return printHelp(on: command)
    }
    do {
      if let status = try runControl(arguments, environment: environment) { return status }
      switch arguments.first {
      case stateName:
        return try runState(arguments.dropFirst(), environment: environment)

      case commandStartedName:
        try runCommandStarted(arguments.dropFirst(), environment: environment)
        return 0

      case commandFinishedName:
        try runCommandFinished(arguments.dropFirst(), environment: environment)
        return 0

      case relayName:
        try runRelay(arguments.dropFirst(), environment: environment, input: standardInput)
        return 0

      // The retired line names no agent, so it reports nothing and exits 0.
      case AgentHookCatalogue.subcommand, AgentHookCatalogue.retiredSubcommand:
        reportAgentHook(agentID(in: arguments), environment: environment, input: standardInput)
        return 0

      case installHooksName:
        try installAgentHooks(arguments.dropFirst())
        return 0

      case removeHooksName:
        try removeAgentHooks(arguments.dropFirst())
        return 0

      case "--version", "version":
        return try printVersion(arguments.dropFirst())

      case let command? where helpCommands.contains(command):
        return arguments.count > 1 ? printHelp(on: arguments[1]) : printHelp(on: nil)

      case nil:
        FileHandle.standardError.write(Data(usage.utf8))
        return 2

      default:
        throw UsageError("unknown command \(arguments[0])")
      }
    } catch let error as UsageError {
      return reportUsageError(error, for: arguments)
    } catch {
      printError("\(error)")
      return 1
    }
  }

  /// Later in the line a help flag may be an option's value, so only a line
  /// that fails to parse is taken as asking for help.
  private static func reportUsageError(_ error: UsageError, for arguments: [String]) -> Int32 {
    if let command = arguments.first, asksForHelp(arguments) { return printHelp(on: command) }
    printError("\(error.message)\n\n\(error.topic.flatMap(usage(of:)) ?? usage)")
    return 2
  }

  /// A help flag in the first `words` after the command, or anywhere before
  /// `--`, after which the words are text.
  private static func asksForHelp(_ arguments: [String], within words: Int = .max) -> Bool {
    guard let command = arguments.first, !helpCommands.contains(command),
      !reportCommands.contains(command)
    else { return false }
    return arguments.dropFirst().prefix(words).prefix { $0 != "--" }
      .contains(where: helpFlags.contains)
  }

  /// `nil` for a command that does not drive the app.
  private static func runControl(
    _ arguments: [String],
    environment: [String: String],
  ) throws
    -> Int32?
  {
    let rest = arguments.dropFirst()
    switch arguments.first {
    case "open": return try runOpen(rest, environment: environment)
    case "quit": return try runQuit(rest, environment: environment)
    case "info": return try runInfo(rest, environment: environment)
    case "config": return try runConfig(rest, environment: environment)
    case "projects": return try runProjects(rest, environment: environment)
    case "worktrees": return try runWorktrees(rest, environment: environment)
    case "tabs": return try runTabs(rest, environment: environment)
    case "panes": return try runPanes(rest, environment: environment)
    case "ui": return try runUI(rest, environment: environment)
    case "board": return try runBoard(rest, environment: environment)
    case "sidebar": return try runSidebar(rest, environment: environment)
    case "window": return try runWindow(rest, environment: environment)
    case "debug": return try runDebug(rest, environment: environment)
    default: return nil
    }
  }

  /// Asked for, so to standard output: it pipes into a pager.
  private static func printHelp(on topic: String?) -> Int32 {
    guard let topic else {
      print(usage, terminator: "")
      return 0
    }
    guard let text = usage(of: topic) else {
      printError("no command \(topic)\n\n\(usage)")
      return 2
    }
    print(text, terminator: "")
    return 0
  }

  private static func printVersion(_ arguments: ArraySlice<String>) throws -> Int32 {
    guard arguments.isEmpty else {
      throw UsageError("--version takes no arguments", topic: "version")
    }
    try printJSON([
      "controlProtocolVersion": ControlRequest.protocolVersion,
      "protocolVersion": SessionStateReport.protocolVersion,
    ])
    return 0
  }

  static func printError(_ message: String) {
    FileHandle.standardError.write(Data("multishell: \(message)\n".utf8))
  }
}
