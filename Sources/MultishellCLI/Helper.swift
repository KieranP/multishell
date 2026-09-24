import Foundation
import MultishellCore
import MultishellProcess

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
        return report(
          SessionState.running, environment: environment, pid: options.int32("pid"),
          command: options["command"])
      case "command-finished":
        let options = try Options(arguments.dropFirst())
        return report(
          SessionState.finished(exitCode: options.int32("exit")), environment: environment,
          duration: options.double("duration"))
      case "relay":
        let options = try Options(arguments.dropFirst())
        relay(environment: environment, input: standardInput, shell: options.int32("pid"))
        return 0
      // `claude-hook` stays: builds before the rename wrote it into
      // settings files that are on disk now and run this line.
      case "agent-hook", "claude-hook":
        agentHook(agentID(in: arguments), environment: environment, input: standardInput)
        return 0
      case "install-agent-hooks":
        let options = try Options(arguments.dropFirst(), names: ["agent"], flags: ["print"])
        return installHooks(try agent(options), print: options.has("print"))
      case "remove-agent-hooks":
        return removeHooks(try agent(Options(arguments.dropFirst(), names: ["agent"])))
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
      pid: options.int32("pid") ?? reportingProcess(environment),
      message: options["message"],
      agent: options["agent"],
      isShell: options["shell"] == "true" ? true : nil,
      subagent: try subagent(options),
      startsTurn: options["new-turn"] == "true" ? true : nil)
    do {
      try send(report, environment: environment)
      return 0
    } catch {
      fail("could not reach Multishell: \(error)")
      return 1
    }
  }

  private static func subagent(_ options: Options) throws -> SubagentReport? {
    guard let id = options["subagent"] else {
      if let orphan = ["subagent-phase", "subagent-type"].first(where: { options[$0] != nil }) {
        throw UsageError("--\(orphan) needs --subagent")
      }
      return nil
    }
    guard let phase = options["subagent-phase"].flatMap(SubagentReport.Phase.init(rawValue:))
    else {
      throw UsageError(
        "--subagent needs --subagent-phase, one of: "
          + SubagentReport.Phase.allCases.map(\.rawValue).joined(separator: ", "))
    }
    return SubagentReport(id: id, type: options["subagent-type"], phase: phase)
  }

  /// Started at the prompt, so it shares the shell's process group: a Ctrl-C
  /// or Ctrl-Z there reaches it too, and a hang-up comes before the last lines.
  private static let relayIgnores = [SIGHUP, SIGINT, SIGQUIT, SIGTSTP, SIGTTIN, SIGTTOU, SIGPIPE]

  /// Ends at EOF or when the shell exits, as a child it started may hold the
  /// pipe open past it. A line it cannot read is dropped: that child could write.
  private static func relay(environment: [String: String], input: FileHandle, shell: Int32?) {
    for number in relayIgnores { _ = signal(number, SIG_IGN) }
    let watch = shell.flatMap { InputOrExitWatch(descriptor: input.fileDescriptor, pid: $0) }
    var pending = Data()
    func relayLines() {
      while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
        relayLine(String(decoding: pending[..<newline], as: UTF8.self), environment: environment)
        pending.removeSubrange(...newline)
      }
    }
    while true {
      if let watch, watch.next() == .exited {
        pending.append(watch.drain())
        relayLines()
        return
      }
      let chunk = input.availableData
      guard !chunk.isEmpty else { return }
      pending.append(chunk)
      relayLines()
    }
  }

  private static func relayLine(_ line: String, environment: [String: String]) {
    let fields = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    guard fields.count == 3 else { return }
    switch fields[0] {
    case "command-started":
      _ = report(
        SessionState.running, environment: environment, pid: Int32(fields[1]),
        command: fields[2])
    case "command-finished":
      _ = report(
        SessionState.finished(exitCode: Int32(fields[1])), environment: environment,
        duration: Double(fields[2]))
    default:
      return
    }
  }

  /// Nothing this prints or returns may disturb the agent: exit 0, no
  /// stdout, and an event that stands for nothing costs one silent process.
  private static func agentHook(
    _ id: String, environment: [String: String], input: FileHandle
  ) {
    let data = input.readDataToEndOfFile()
    guard let integration = AgentHooks.integration(for: id),
      let payload = AgentHookPayload(json: data), integration.event(for: payload) != nil
    else { return }
    let pid = reportingProcess(environment)
    guard
      let report = integration.report(
        for: payload,
        session: environment[SessionEnvironment.sessionKey].flatMap { UUID(uuidString: $0) },
        cwd: environment[SessionEnvironment.worktreeKey], pid: pid,
        backgroundShells: { backgroundShells(of: pid, marker: $0) })
    else { return }
    try? send(report, environment: environment)
  }

  /// A Stop comes with no tool running, so any tool shell still alive under
  /// the agent is one it backgrounded. `nil` for none, keeping the line short.
  private static func backgroundShells(of agent: Int32, marker: String) -> [Int32]? {
    let shells = ProcessAncestry.children(of: agent, whoseArgumentsContain: marker)
    return shells.isEmpty ? nil : shells
  }

  /// A state with no message, for the shell hooks. The pid, when given, is
  /// the shell's, a command's not being known in a preexec hook.
  private static func report(
    _ state: SessionState, environment: [String: String], pid: Int32? = nil,
    duration: Double? = nil, command: String? = nil
  ) -> Int32 {
    let report = SessionStateReport(
      state: state,
      sessionID: environment[SessionEnvironment.sessionKey].flatMap { UUID(uuidString: $0) },
      cwd: environment[SessionEnvironment.worktreeKey],
      pid: pid,
      duration: duration,
      command: command,
      isShell: true)
    do {
      try send(report, environment: environment)
      return 0
    } catch {
      // A shell hook must never make the prompt print an error.
      return 0
    }
  }

  /// The program that ran this, the walk stopping short of the app itself:
  /// from a prompt in one of its tabs that leaves the shell, whose exit clears.
  private static func reportingProcess(_ environment: [String: String]) -> Int32 {
    ProcessAncestry.reportingProcess(
      stoppingAt: environment[SessionEnvironment.appPIDKey].flatMap { Int32($0) })
  }

  private static func send(_ report: SessionStateReport, environment: [String: String]) throws {
    let socket =
      environment[SessionEnvironment.socketKey].map { URL(fileURLWithPath: $0) }
      ?? Paths.socketFile
    try UnixSocketClient.send(try report.encodedLine(), to: socket)
  }

  /// Which agent a hook line names, Claude Code when it names none. Read by
  /// hand, since a hook must never fail over an argument.
  private static func agentID(in arguments: [String]) -> String {
    guard let flag = arguments.firstIndex(of: "--agent"), flag + 1 < arguments.count else {
      return AgentCatalogue.claudeID
    }
    return arguments[flag + 1]
  }

  /// A person typed this line, so a missing agent is refused, not guessed.
  private static func agent(_ options: Options) throws -> AgentHookIntegration {
    guard let id = options["agent"] else { throw UsageError("--agent is required") }
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

/// `--name value` pairs and bare `--flag`s after the subcommand. Anything
/// else is a usage error, so a typo in a hook line is caught rather than ignored.
struct Options {
  private let values: [String: String]
  private let setFlags: Set<String>

  /// `names` limits the pairs accepted; nil takes any.
  init(
    _ arguments: ArraySlice<String>, names: Set<String>? = nil, flags: Set<String> = []
  ) throws {
    var values: [String: String] = [:]
    var setFlags: Set<String> = []
    var rest = arguments
    while let argument = rest.popFirst() {
      let name = String(argument.dropFirst(2))
      guard argument.hasPrefix("--") else { throw UsageError("unexpected argument \(argument)") }
      if flags.contains(name) {
        setFlags.insert(name)
        continue
      }
      guard names?.contains(name) ?? true, let value = rest.popFirst() else {
        throw UsageError("unexpected argument \(argument)")
      }
      values[name] = value
    }
    self.values = values
    self.setFlags = setFlags
  }

  subscript(name: String) -> String? { values[name] }

  func has(_ flag: String) -> Bool { setFlags.contains(flag) }

  func int32(_ name: String) -> Int32? { values[name].flatMap { Int32($0) } }

  func double(_ name: String) -> Double? { values[name].flatMap { Double($0) } }
}

struct UsageError: Error {
  let message: String
  init(_ message: String) { self.message = message }
}
