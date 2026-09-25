import Foundation
import MultishellCore

/// The `multishell` command: reports a session's state over the socket and
/// installs the agent hooks. Silent from a hook, loud from the terminal.
enum Helper {
  static let usage = """
    usage:
      multishell state <running|attention|done|error|idle> [--session ID] [--cwd PATH]
                       [--pid PID] [--message TEXT] [--agent ID]
                       [--subagent ID --subagent-phase <started|working|ended>
                        [--subagent-type NAME]] [--new-turn true] [--shell true]
          Report a state for the terminal this runs in. Defaults come from the
          environment the app sets: MULTISHELL_SESSION, MULTISHELL_WORKTREE,
          MULTISHELL_SOCKET, MULTISHELL_APP_PID. The pid defaults to the
          nearest ancestor that is not a shell: the program that ran this, or
          the shell itself when the next ancestor is the app. --agent names
          the agent at the prompt, by catalogue id, so the app can tell an
          agent's pane from a plain shell; the agents' own hooks set it.
          --subagent names a worker the agent has out, so the app can list
          it: started and ended are its ends, working a tool call inside it.
          --new-turn marks the prompt starting a turn, after which no worker
          of the last one is still out. --shell says the injected shell
          integration sent this, which is what may take back the mark a
          command put on a pane; nothing else sets it.
      multishell command-started [--pid N] [--command WORD]
          Report that a foreground command has started (running). For a shell
          preexec hook; pass the shell's pid so the state clears if the shell
          exits without a prompt. --command names the program it runs, its
          first word without a path, which marks the pane where that program
          is an agent nobody has installed hooks for.
      multishell command-finished --exit N [--duration S]
          Report that it finished: done when N is 0 or a signal, failed
          otherwise. For a shell precmd hook; a short duration posts no
          notification.
      multishell relay [--pid N]
          Read `command-started PID WORD` and `command-finished EXIT SECONDS`
          lines from stdin until it closes or process N exits, reporting each
          as the two commands above do. One per bash shell, whose pid is N, so
          a command costs no process launch.
      multishell agent-hook --agent ID
          Read that agent's hook payload from stdin and report the state its
          event stands for. Always exits 0. Known agents:
          \(knownAgents).
      multishell install-agent-hooks --agent ID [--print]
          Write the hooks into that agent's own file, or print them.
      multishell remove-agent-hooks --agent ID
      multishell --version

    """

  static let knownAgents = AgentHookCatalogue.integrations.map(\.id).joined(separator: ", ")

  static func run(
    _ arguments: [String], environment: [String: String], standardInput: FileHandle
  )
    -> Int32
  {
    do {
      switch arguments.first {
      case "state":
        return try state(Array(arguments.dropFirst()), environment: environment)
      case "command-started":
        let options = try CommandOptions(arguments.dropFirst())
        reportShellState(
          SessionState.running, environment: environment, pid: options.int32("pid"),
          command: options["command"])
        return 0
      case "command-finished":
        let options = try CommandOptions(arguments.dropFirst())
        reportShellState(
          SessionState.finished(exitCode: options.int32("exit")), environment: environment,
          duration: options.double("duration"))
        return 0
      case "relay":
        let options = try CommandOptions(arguments.dropFirst())
        relay(environment: environment, input: standardInput, shellPID: options.int32("pid"))
        return 0
      // `claude-hook` stays: builds before the rename wrote it into
      // settings files that are on disk now and run this line.
      case "agent-hook", "claude-hook":
        agentHook(agentID(in: arguments), environment: environment, input: standardInput)
        return 0
      case "install-agent-hooks":
        let options = try CommandOptions(arguments.dropFirst(), names: ["agent"], flags: ["print"])
        return installHooks(try requiredIntegration(options), print: options.has("print"))
      case "remove-agent-hooks":
        return removeHooks(
          try requiredIntegration(CommandOptions(arguments.dropFirst(), names: ["agent"])))
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
      fail("\(error.message)\n\n\(usage)")
      return 2
    } catch {
      fail("\(error)")
      return 1
    }
  }

  static func fail(_ message: String) {
    FileHandle.standardError.write(Data("multishell: \(message)\n".utf8))
  }
}
