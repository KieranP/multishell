import Foundation
import MultishellCore
import MultishellProcess
import Testing

/// The built `multishell` binary against a real socket: what a hook does,
/// end to end, minus Claude itself.
@Suite(.serialized)
struct HelperTests {
  private final class LineRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    func record(_ line: String) { lock.withLock { lines.append(line) } }
    var received: [String] { lock.withLock { lines } }
  }

  /// `.build/debug/multishell`, found from this file: the test bundle's own
  /// location differs between the swift-testing helper and xctest.
  private static var helper: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/debug/multishell")
  }

  private func socketPath() -> URL {
    URL(fileURLWithPath: "/tmp/ms-cli-\(UUID().uuidString.prefix(8)).sock")
  }

  private func run(
    _ arguments: [String], environment: [String: String] = [:], stdin: String? = nil,
    via executable: URL? = nil
  ) async throws -> ProcessOutput {
    var env = environment
    env["PATH"] = ProcessInfo.processInfo.environment["PATH"]
    let runner = ProcessRunner()
    guard let stdin else {
      return try await runner.capture(
        executable ?? Self.helper, arguments, in: URL(fileURLWithPath: "/tmp"), environment: env)
    }
    // Stdin through a shell pipe, since the runner gives children /dev/null.
    let quoted = ShellQuoting.quote(stdin)
    let command =
      "printf '%s' \(quoted) | \(ShellQuoting.quote(Self.helper.path)) "
      + ShellQuoting.commandLine(arguments)
    return try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", command], in: URL(fileURLWithPath: "/tmp"),
      environment: env)
  }

  private func waitUntil(_ condition: @escaping () -> Bool) async throws {
    for _ in 0..<160 where !condition() {
      try await Task.sleep(for: .milliseconds(50))
    }
  }

  @Test func stateReachesTheServerWithTheSessionFromTheEnvironment() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()
    let session = UUID()

    let output = try await run(
      ["state", "running", "--pid", "4242"],
      environment: [
        "MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString,
        "MULTISHELL_WORKTREE": "/w/repo",
      ])

    #expect(output.succeeded, "\(output.standardError)")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.state == .running)
    #expect(report?.sessionID == session)
    #expect(report?.cwd == "/w/repo")
    #expect(report?.pid == 4242)
    #expect(report?.version == SessionStateReport.protocolVersion)
  }

  @Test func anAgentHookPayloadBecomesTheMatchingReportAndAlwaysExitsZero() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()
    let session = UUID()
    let payload = #"""
      {"session_id":"s","cwd":"/w/repo","hook_event_name":"Notification",
       "message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}
      """#

    let output = try await run(
      ["claude-hook"],
      environment: ["MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString],
      stdin: payload)

    #expect(output.succeeded)
    #expect(output.standardOutput.isEmpty, "Claude reads a hook's stdout")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.state == .attention)
    #expect(report?.sessionID == session)
    #expect(report?.message == "Claude needs your permission to use Bash")
    #expect((report?.pid ?? 0) > 0, "the parent's pid, for staleness checks")
    #expect(report?.agent == AgentCatalogue.claudeID, "who is at that prompt")

    // An event that says nothing, and no app at all: both exit 0 in silence.
    let ignored = try await run(
      ["claude-hook"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"PreCompact","cwd":"/w"}"#)
    #expect(ignored.succeeded && ignored.standardOutput.isEmpty && ignored.standardError.isEmpty)
    let orphan = try await run(
      ["claude-hook"], environment: ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"],
      stdin: #"{"hook_event_name":"Stop","cwd":"/w"}"#)
    #expect(orphan.succeeded && orphan.standardError.isEmpty)
    try await Task.sleep(for: .milliseconds(200))
    #expect(recorder.received.count == 1)

    // The same line for an agent whose events are named its own way: a
    // Gemini turn that has ended is Done, and Gemini is at that prompt.
    let gemini = try await run(
      ["agent-hook", "--agent", "gemini"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"AfterAgent","cwd":"/w/repo"}"#)
    #expect(gemini.succeeded && gemini.standardOutput.isEmpty)
    try await waitUntil { recorder.received.count == 2 }
    let second = SessionStateReport.parse(recorder.received.last ?? "")
    #expect(second?.state == .done)
    #expect(second?.agent == "gemini")
    #expect(second?.cwd == "/w/repo")

    // Claude says one prompt twice. The request comes as it is asked and
    // moves the dot without a banner; its notification, above, is the one
    // that speaks and the one that carries the wording.
    let request = try await run(
      ["agent-hook", "--agent", "claude"],
      environment: ["MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString],
      stdin: #"""
        {"hook_event_name":"PermissionRequest","cwd":"/w/repo",
         "permission_mode":"default","tool_name":"Bash"}
        """#)
    #expect(request.succeeded && request.standardOutput.isEmpty)
    try await waitUntil { recorder.received.count == 3 }
    let third = SessionStateReport.parse(recorder.received.last ?? "")
    #expect(third?.state == .attention)
    #expect(third?.silent == true)
    #expect(third?.message == nil)

    // The mode where a classifier answers the prompt: nobody is waiting,
    // so nothing is said at all.
    let classifier = try await run(
      ["agent-hook", "--agent", "claude"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"""
        {"hook_event_name":"PermissionRequest","cwd":"/w/repo","permission_mode":"auto"}
        """#)
    #expect(classifier.succeeded && classifier.standardError.isEmpty)
    try await Task.sleep(for: .milliseconds(200))
    #expect(recorder.received.count == 3)
  }

  /// Any tool can say which agent is at the prompt, the way Claude's hooks
  /// do, so the app writes a dropped file the way that agent reads one.
  @Test func stateCanNameTheAgentAtThePrompt() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let output = try await run(
      ["state", "running", "--agent", "codex"], environment: ["MULTISHELL_SOCKET": path.path])
    #expect(output.succeeded, "\(output.standardError)")

    try await waitUntil { !recorder.received.isEmpty }
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.agent == "codex")
  }

  /// The pid reported is the program that ran the hook, past any shells
  /// between: here the test process, two `sh -c` layers up.
  @Test func thePidReportedIsTheFirstNonShellAncestor() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let inner = "\(ShellQuoting.quote(Self.helper.path)) state running"
    let output = try await run(
      ["-c", "/bin/sh -c \(ShellQuoting.quote(inner))"],
      environment: ["MULTISHELL_SOCKET": path.path], via: URL(fileURLWithPath: "/bin/sh"))
    #expect(output.succeeded, "\(output.standardError)")

    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.pid == ProcessInfo.processInfo.processIdentifier)
  }

  @Test func commandStartedAndFinishedMapToRunningDoneAndFailed() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()
    let session = UUID()
    let env = [
      "MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString,
      "MULTISHELL_WORKTREE": "/w/repo",
    ]

    #expect(try await run(["command-started", "--pid", "4242"], environment: env).succeeded)
    #expect(
      try await run(["command-finished", "--exit", "0", "--duration", "3.5"], environment: env)
        .succeeded)
    #expect(try await run(["command-finished", "--exit", "2"], environment: env).succeeded)
    #expect(try await run(["command-finished", "--exit", "130"], environment: env).succeeded)

    try await waitUntil { recorder.received.count == 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states == [.running, .done, .error, .done], "signals are not failures")
    #expect(SessionStateReport.parse(recorder.received[1])?.duration == 3.5)
    #expect(SessionStateReport.parse(recorder.received[2])?.duration == nil)
    #expect(SessionStateReport.parse(recorder.received[0])?.sessionID == session)
    #expect(SessionStateReport.parse(recorder.received[0])?.cwd == "/w/repo")
    #expect(
      SessionStateReport.parse(recorder.received[0])?.pid == 4242,
      "the shell's pid, so a shell that exits mid-command clears its Working")
  }

  /// The generated ZDOTDIR files, driven by a real zsh: the user's own
  /// .zshrc still loads (so nothing is lost by the redirection), and the
  /// injected hooks report running then done/failed.
  @Test func zshIntegrationLoadsUserConfigAndReportsThroughInjectedHooks() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-inject-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: integration, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
    for (name, contents) in ShellStateHooks.zshIntegrationFiles(helper: Self.helper.path) {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    // The user's own .zshrc, which must still run despite the redirection.
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: userZdotdir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let session = UUID()
    var env = ProcessInfo.processInfo.environment
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = session.uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    // Interactive zsh loads our .zshrc (which sources the user's and adds
    // the hooks); then drive the hooks around a good and a bad command.
    let script = """
      printf 'loaded=%s zdotdir=%s\\n' "$MULTISHELL_USER_RC_LOADED" "$ZDOTDIR"
      _multishell_preexec; true; _multishell_precmd
      _multishell_preexec; false; _multishell_precmd
      wait
      """
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"), ["-i", "-c", script], in: root, environment: env)

    #expect(
      output.standardOutput.contains("loaded=yes"),
      "the user's .zshrc did not run: \(output.standardOutput)")
    #expect(
      output.standardOutput.contains("zdotdir=\(userZdotdir.path)"),
      "ZDOTDIR was not handed back to the user for nested shells: \(output.standardOutput)")

    try await waitUntil { recorder.received.count >= 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states.filter { $0 == .running }.count == 2, "\(states)")
    #expect(states.contains(.done) && states.contains(.error), "\(states)")
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.sessionID == session)
  }

  /// `%f` writes the locale's decimal separator, so a comma region sent
  /// `"duration":1,234` and the reader dropped the whole report.
  @Test func aCommaDecimalLocaleStillSendsAReportThatParses() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    // Skips where the locale is absent rather than failing on its absence.
    let comma = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"), ["-c", "printf '%.3f' 1.5"],
      in: URL(fileURLWithPath: "/tmp"), environment: ["LC_ALL": "de_DE.UTF-8"])
    guard comma.standardOutput.contains(",") else { return }

    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-locale-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    // Empty, so the chain does not reach the developer's own .zshrc, which
    // sets a locale of its own and would decide this test.
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: integration, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
    for (name, contents) in ShellStateHooks.zshIntegrationFiles(helper: Self.helper.path) {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    var env = ProcessInfo.processInfo.environment
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    env["LC_ALL"] = "de_DE.UTF-8"
    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      ["-i", "-c", "_multishell_preexec; true; _multishell_precmd; wait"], in: root,
      environment: env)

    try await waitUntil { recorder.received.count >= 2 }
    let finished = recorder.received.compactMap(SessionStateReport.parse).filter {
      $0.state == .done
    }
    #expect(finished.count == 1, "unparsed: \(recorder.received)")
    #expect(finished.first?.duration != nil, "the duration is what the separator broke")
  }

  /// The generated bash init, as `--init-file` would read it: the user's own
  /// .bashrc still loads, and the injected hooks report running then done
  /// and failed.
  @Test func bashInitLoadsUserConfigAndReportsThroughInjectedHooks() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let home = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-bash-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: Self.helper.path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)

    let session = UUID()
    var env = ProcessInfo.processInfo.environment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = session.uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    // An interactive bash reading our init in place of .bashrc, then the
    // hooks driven by hand around a passing and a failing command.
    let script = """
      printf 'loaded=%s\\n' "$MULTISHELL_USER_RC_LOADED"
      _multishell_command_started; true; _multishell_precmd
      _multishell_command_started; false; _multishell_precmd
      wait
      """
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/bash"), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env)

    #expect(
      output.standardOutput.contains("loaded=yes"),
      "the user's .bashrc did not load: \(output.standardOutput) \(output.standardError)")
    try await waitUntil { recorder.received.count >= 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states.filter { $0 == .running }.count == 2, "\(states)")
    #expect(states.contains(.done) && states.contains(.error), "\(states)")
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.sessionID == session)
    let durations = recorder.received.compactMap { SessionStateReport.parse($0)?.duration }
    #expect(durations.count == 2 && durations.allSatisfy { $0 >= 0 }, "\(durations)")
  }

  /// A user whose ~/.zshenv sets ZDOTDIR keeps their config: the chain
  /// follows the directory their .zshenv leaves, not $HOME.
  @Test func zshIntegrationFollowsAZdotdirSetByTheUsersZshenv() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-relocate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let relocated = home.appendingPathComponent(".config/zsh", isDirectory: true)
    for dir in [integration, relocated] {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    for (name, contents) in ShellStateHooks.zshIntegrationFiles(helper: Self.helper.path) {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    try "export ZDOTDIR=\"$HOME/.config/zsh\"\n".write(
      to: home.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=relocated\n".write(
      to: relocated.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    var env = ProcessInfo.processInfo.environment
    env["HOME"] = home.path
    env["ZDOTDIR"] = integration.path
    env.removeValue(forKey: "MULTISHELL_USER_ZDOTDIR")
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      [
        "-i", "-c",
        "printf '%s|%s' \"$MULTISHELL_USER_RC_LOADED\" \"$ZDOTDIR\"; _multishell_preexec",
      ],
      in: root, environment: env)

    let fields = output.standardOutput.split(separator: "|", omittingEmptySubsequences: false)
    #expect(
      fields.first == "relocated", "the relocated .zshrc did not run: \(output.standardOutput)")
    #expect(
      fields.count == 2 && fields[1] == relocated.path,
      "ZDOTDIR handed back to the relocated dir: \(output.standardOutput)")
    try await waitUntil { !recorder.received.isEmpty }
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.state == .running)
  }

  @Test func stateWithNobodyListeningFailsLoudly() async throws {
    let output = try await run(
      ["state", "done"], environment: ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"])
    #expect(output.status == 1)
    #expect(output.standardError.contains("could not reach Multishell"))
  }

  @Test func usageErrorsExitTwo() async throws {
    #expect(try await run([]).status == 2)
    #expect(try await run(["state", "sleeping"]).status == 2)
    #expect(try await run(["state", "done", "--bogus"]).status == 2)
    #expect(try await run(["frobnicate"]).status == 2)
    let version = try await run(["--version"])
    #expect(version.succeeded && version.standardOutput.contains("protocol version 1"))
  }

  @Test func printingTheHooksGivesTheSnippetWithoutTouchingAnyFile() async throws {
    let claude = try await run(["install-agent-hooks", "--agent", "claude", "--print"])
    #expect(claude.succeeded)
    let object =
      try JSONSerialization.jsonObject(with: Data(claude.standardOutput.utf8)) as? [String: Any]
    #expect(AgentHooks.claude.isInstalled(in: object ?? [:]))

    let copilot = try await run(["install-agent-hooks", "--agent", "copilot", "--print"])
    #expect(copilot.succeeded)
    let file =
      try JSONSerialization.jsonObject(with: Data(copilot.standardOutput.utf8)) as? [String: Any]
    #expect(file?["version"] as? Int == 1)

    let plugin = try await run(["install-agent-hooks", "--agent", "opencode", "--print"])
    #expect(plugin.succeeded && plugin.standardOutput.contains("MultishellPlugin"))

    let unknown = try await run(["install-agent-hooks", "--agent", "aider"])
    #expect(unknown.status == 2 && unknown.standardError.contains("no hooks for aider"))
  }
}
