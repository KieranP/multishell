import Foundation
import MultishellCore
import MultishellProcess

/// The `multishell` command: reports a session's state to the running app
/// over its socket, and installs the agent hooks that do so.
///
/// Small enough to hand-parse. Every failure to reach the app is silent
/// from a hook and loud from the terminal: a hook fires with or without
/// Multishell running and must never make an agent show an error for it.
enum Helper {
  static let usage = """
    usage:
      multishell state <running|attention|done|error|idle> [--session ID] [--cwd PATH]
                       [--pid PID] [--message TEXT] [--agent ID]
          Report a state for the terminal this runs in. Defaults come from the
          environment the app sets: MULTISHELL_SESSION, MULTISHELL_WORKTREE,
          MULTISHELL_SOCKET. The pid defaults to the nearest ancestor that is
          not a shell: the program that ran this. --agent names the agent at
          the prompt, by catalogue id, so the app can tell an agent's pane
          from a plain shell; the agents' own hooks set it.
      multishell command-started [--pid N]
          Report that a foreground command has started (running). For a shell
          preexec hook; pass the shell's pid so the state clears if the shell
          exits without a prompt.
      multishell command-finished --exit N [--duration S]
          Report that it finished: done when N is 0 or a signal, failed
          otherwise. For a shell precmd hook; a short duration posts no
          notification.
      multishell agent-hook --agent ID
          Read that agent's hook payload from stdin and report the state its
          event stands for. Always exits 0. Known agents:
          \(AgentHooks.integrations.map(\.id).joined(separator: ", ")).
      multishell install-agent-hooks --agent ID [--print]
          Write the hooks into that agent's own file, or print them.
      multishell remove-agent-hooks --agent ID
      multishell --version

    """

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
        let options = try Options(arguments.dropFirst())
        return report(SessionState.running, environment: environment, pid: options.int32("pid"))
      case "command-finished":
        let options = try Options(arguments.dropFirst())
        return report(
          SessionState.finished(exitCode: options.int32("exit")), environment: environment,
          duration: options.double("duration"))
      // `claude-hook` stays, and is not the `install-claude-hooks` kind of
      // alias those two were: it is written into `~/.claude/settings.json`
      // by builds before the rename, so those files are on disk now and
      // run this line. Removing it exits 2 on every hook an older install
      // wrote and takes that user's state dots with it, silently.
      // `AgentHooks.isMultishellHook` matches it for the same reason.
      case "agent-hook", "claude-hook":
        agentHook(agentID(in: arguments), environment: environment, input: standardInput)
        return 0
      case "install-agent-hooks":
        return installHooks(try agent(in: arguments), print: arguments.contains("--print"))
      case "remove-agent-hooks":
        return removeHooks(try agent(in: arguments))
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

  // MARK: - state

  private static func state(_ arguments: [String], environment: [String: String]) throws -> Int32 {
    guard let name = arguments.first, let state = SessionState(rawValue: name) else {
      throw UsageError(
        "state needs one of: \(SessionState.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    let options = try Options(arguments.dropFirst())
    let report = SessionStateReport(
      state: state,
      sessionID: (options["session"] ?? environment[SessionEnvironment.sessionKey]).flatMap {
        UUID(uuidString: $0)
      },
      cwd: options["cwd"] ?? environment[SessionEnvironment.worktreeKey]
        ?? FileManager.default.currentDirectoryPath,
      pid: options.int32("pid") ?? ProcessAncestry.reportingProcess(),
      message: options["message"],
      agent: options["agent"])
    do {
      try send(report, environment: environment)
      return 0
    } catch {
      fail("could not reach Multishell: \(error)")
      return 1
    }
  }

  // MARK: - agent-hook

  /// Nothing this prints or returns may disturb the agent: exit 0, no
  /// stdout, and an event that stands for nothing costs one silent process.
  private static func agentHook(
    _ id: String, environment: [String: String], input: FileHandle
  ) {
    let data = input.readDataToEndOfFile()
    guard
      let integration = AgentHooks.integration(for: id),
      let payload = AgentHookPayload(json: data),
      let event = integration.event(for: payload)
    else { return }
    let report = SessionStateReport(
      state: event.state,
      sessionID: environment[SessionEnvironment.sessionKey].flatMap { UUID(uuidString: $0) },
      cwd: payload.cwd ?? environment[SessionEnvironment.worktreeKey],
      pid: ProcessAncestry.reportingProcess(),
      message: payload.message,
      agent: id,
      silent: event.silent ? true : nil)
    try? send(report, environment: environment)
  }

  /// A state with no message, for the shell hooks: the session and cwd come
  /// from the environment the app set. The pid, when given, is the shell's:
  /// a command's own pid is not known in a preexec hook, and the shell's is
  /// what lets the app clear Working when `exit` ends it without a prompt.
  private static func report(
    _ state: SessionState, environment: [String: String], pid: Int32? = nil,
    duration: Double? = nil
  ) -> Int32 {
    let report = SessionStateReport(
      state: state,
      sessionID: environment[SessionEnvironment.sessionKey].flatMap { UUID(uuidString: $0) },
      cwd: environment[SessionEnvironment.worktreeKey],
      pid: pid,
      duration: duration)
    do {
      try send(report, environment: environment)
      return 0
    } catch {
      // A shell hook must never make the prompt print an error.
      return 0
    }
  }

  private static func send(_ report: SessionStateReport, environment: [String: String]) throws {
    let socket =
      environment[SessionEnvironment.socketKey].map { URL(fileURLWithPath: $0) }
      ?? Paths.socketFile
    try UnixSocketClient.send(try report.encodedLine(), to: socket)
  }

  // MARK: - hooks

  /// Which agent the line names. Claude Code when it names none: its hooks
  /// were installed before there was a flag, and those lines are still in
  /// the settings files that install wrote. Read by hand rather than
  /// through `Options`, since a hook must never fail over an argument.
  private static func agentID(in arguments: [String]) -> String {
    guard let flag = arguments.firstIndex(of: "--agent"), flag + 1 < arguments.count else {
      return AgentCatalogue.claudeID
    }
    return arguments[flag + 1]
  }

  private static func agent(in arguments: [String]) throws -> AgentHookIntegration {
    let id = agentID(in: arguments)
    guard let integration = AgentHooks.integration(for: id) else {
      throw UsageError(
        "no hooks for \(id); known agents: "
          + AgentHooks.integrations.map(\.id).joined(separator: ", "))
    }
    return integration
  }

  private static func installHooks(
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

  private static func removeHooks(_ integration: AgentHookIntegration) -> Int32 {
    do {
      try integration.remove()
      print("\(integration.name) hooks removed from \(integration.file.path)")
      return 0
    } catch {
      fail("\(error)")
      return 1
    }
  }

  private static func fail(_ message: String) {
    FileHandle.standardError.write(Data("multishell: \(message)\n".utf8))
  }
}

/// `--name value` pairs after the subcommand. Anything else is a usage
/// error, so a typo in a hook line is caught rather than ignored.
struct Options {
  private let values: [String: String]

  init(_ arguments: ArraySlice<String>) throws {
    var values: [String: String] = [:]
    var rest = arguments
    while let flag = rest.popFirst() {
      guard flag.hasPrefix("--"), let value = rest.popFirst() else {
        throw UsageError("unexpected argument \(flag)")
      }
      values[String(flag.dropFirst(2))] = value
    }
    self.values = values
  }

  subscript(name: String) -> String? { values[name] }

  func int32(_ name: String) -> Int32? { values[name].flatMap { Int32($0) } }

  func double(_ name: String) -> Double? { values[name].flatMap { Double($0) } }
}

struct UsageError: Error {
  let message: String
  init(_ message: String) { self.message = message }
}
