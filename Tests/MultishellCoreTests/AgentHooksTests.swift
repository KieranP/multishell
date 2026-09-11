import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentHookPayloadTests {
  private func state(
    _ integration: AgentHookIntegration, _ event: String, mode: String? = nil
  ) -> SessionState? {
    integration.event(for: AgentHookPayload(eventName: event, permissionMode: mode))?.state
  }

  @Test func eachAgentsEventsMapToTheStatesTheyStandFor() {
    let claude = AgentHooks.claude
    #expect(state(claude, "UserPromptSubmit") == .running)
    #expect(state(claude, "PreToolUse") == .running)
    #expect(state(claude, "PostToolUse") == .running)
    #expect(state(claude, "PermissionRequest") == .attention)
    #expect(state(claude, "PermissionDenied") == nil, "only an auto-mode classifier's refusal")
    #expect(state(claude, "Notification") == .attention)
    #expect(state(claude, "Stop") == .done)
    #expect(state(claude, "StopFailure") == .error)
    #expect(state(claude, "SessionEnd") == .idle)
    #expect(state(claude, "SessionStart") == .idle)
    #expect(state(claude, "SubagentStop") == nil, "the agent is still working")
    #expect(state(claude, "SubagentStart") == nil, "the tool call already said working")
    #expect(state(claude, "PostToolUseFailure") == nil, "a tool failing is not a turn failing")
    #expect(state(claude, "PreCompact") == nil)
    #expect(state(claude, "PostCompact") == nil, "it fires when the compaction is over")
    #expect(state(claude, "SomethingNew") == nil)

    let codex = AgentHooks.codex
    #expect(state(codex, "PermissionRequest") == .attention, "Codex's own Notification")
    #expect(state(codex, "Stop") == .done)
    #expect(state(codex, "Interrupt") == .idle, "the turn ended, nothing finished")
    #expect(state(codex, "Notification") == nil, "an event Codex does not have")

    let gemini = AgentHooks.gemini
    #expect(state(gemini, "BeforeAgent") == .running)
    #expect(state(gemini, "BeforeTool") == .running)
    #expect(state(gemini, "AfterAgent") == .done)
    #expect(state(gemini, "Notification") == .attention)
    #expect(state(gemini, "Stop") == nil, "Gemini names its own events")
  }

  /// Codex asks its hook before it decides whether a call needs anyone at
  /// all, so under a mode that never stops, a permission request is work in
  /// progress and not a question. Reporting it as waiting would put a
  /// banner on every tool call of a full-auto run.
  @Test func codexOnlyWaitsInAModeThatStopsForTheUser() {
    let codex = AgentHooks.codex
    #expect(state(codex, "PermissionRequest", mode: "default") == .attention)
    #expect(state(codex, "PermissionRequest", mode: "acceptEdits") == .attention)
    #expect(state(codex, "PermissionRequest", mode: "dontAsk") == nil)
    #expect(state(codex, "PermissionRequest", mode: "bypassPermissions") == nil)
    #expect(
      state(codex, "PermissionRequest", mode: nil) == .attention, "said nothing: assume it asks")
    #expect(
      state(codex, "PermissionRequest", mode: "a-mode-from-a-later-codex") == .attention,
      "an amber dot too early beats one that never comes")
    #expect(state(codex, "Stop", mode: "dontAsk") == .done, "the mode governs that event only")
  }

  /// Claude asks the hook before it decides whether a call needs anyone at
  /// all, the same as Codex, so the mode governs the request there too. Its
  /// `auto` is the mode a classifier answers in.
  @Test func claudeOnlyWaitsOnARequestInAModeThatStopsForTheUser() {
    let claude = AgentHooks.claude
    #expect(state(claude, "PermissionRequest", mode: "default") == .attention)
    #expect(state(claude, "PermissionRequest", mode: "plan") == .attention)
    #expect(state(claude, "PermissionRequest", mode: "auto") == nil)
    #expect(state(claude, "PermissionRequest", mode: "bypassPermissions") == nil)
    #expect(
      state(claude, "Notification", mode: "auto") == .attention,
      "the mode governs that event only")
  }

  /// Claude reports a standing prompt twice, immediately and again six
  /// seconds later. Both move the dot; only the second is worth a banner.
  @Test func claudeAsksTwiceForOnePromptAndOnlyOneOfThemIsHeard() throws {
    let claude = AgentHooks.claude
    let request = try #require(claude.event(for: AgentHookPayload(eventName: "PermissionRequest")))
    let notification = try #require(claude.event(for: AgentHookPayload(eventName: "Notification")))
    #expect(request.state == notification.state)
    #expect(request.silent)
    #expect(!notification.silent)
    #expect(claude.events.filter(\.silent).count == 1)
    #expect(AgentHooks.integrations.allSatisfy { $0.events.filter(\.silent).count <= 1 })
  }

  /// Copilot takes `notification` in its file and reports `Notification`;
  /// a hook that read one name for the other would map nothing.
  @Test func copilotIsAskedByOneNameAndReportsByAnother() throws {
    let copilot = AgentHooks.copilot
    let event = try #require(copilot.events.first { $0.state == .attention })
    #expect(event.name == "notification")
    #expect(event.reported == "Notification")
    #expect(state(copilot, "Notification") == .attention)
    #expect(state(copilot, "notification") == nil, "what the payload says decides")
    #expect(state(copilot, "Stop") == .done)
  }

  /// Copilot raises a notification for a background shell finishing as
  /// much as for a question, and only the questions are worth an amber
  /// dot; the type is asked for in the file rather than sorted out here.
  @Test func copilotAsksOnlyForTheNotificationsThatAreQuestions() throws {
    let event = try #require(AgentHooks.copilot.events.first { $0.state == .attention })
    #expect(event.matcher == "permission_prompt|elicitation_dialog")
    #expect(
      AgentHooks.copilot.events.allSatisfy { $0.state == .attention || $0.matcher == nil },
      "nothing else needs filtering")
    #expect(
      AgentHooks.gemini.events.allSatisfy { $0.matcher == nil },
      "Gemini raises a Notification for a tool permission and nothing else")
  }

  @Test func theStdinPayloadYieldsEventDirectoryAndMessage() {
    let payload = AgentHookPayload(
      json: Data(
        #"""
        { "session_id": "abc", "transcript_path": "/t", "cwd": "/w/repo",
          "hook_event_name": "Notification", "message": "Claude needs your permission",
          "notification_type": "permission_prompt" }
        """#.utf8))
    #expect(payload?.eventName == "Notification")
    #expect(payload?.cwd == "/w/repo")
    #expect(payload?.message == "Claude needs your permission")
    #expect(state(AgentHooks.claude, payload?.eventName ?? "") == .attention)
  }

  /// Codex and Copilot write the same three fields under the same names,
  /// which is why one parser serves all four agents.
  @Test func theOtherAgentsWriteTheSameFields() {
    let codex = AgentHookPayload(
      json: Data(
        #"""
        { "cwd": "/w/repo", "hook_event_name": "PermissionRequest", "model": "gpt-5",
          "permission_mode": "default", "session_id": "s", "transcript_path": null,
          "tool_name": "shell", "turn_id": "t" }
        """#.utf8))
    #expect(codex?.eventName == "PermissionRequest")
    #expect(codex?.cwd == "/w/repo")
    #expect(codex?.message == nil)

    let copilot = AgentHookPayload(
      json: Data(
        #"""
        { "sessionId": "s", "timestamp": 1, "cwd": "/w/repo",
          "hook_event_name": "Notification", "message": "Permission needed",
          "notification_type": "permission_prompt" }
        """#.utf8))
    #expect(copilot?.eventName == "Notification")
    #expect(copilot?.message == "Permission needed")
  }

  @Test func aPayloadWithoutAnEventNameIsNotAPayload() {
    #expect(AgentHookPayload(json: Data(#"{"cwd":"/w"}"#.utf8)) == nil)
    #expect(AgentHookPayload(json: Data("nope".utf8)) == nil)
    #expect(AgentHookPayload(json: Data()) == nil)
  }
}

@Suite
struct AgentHooksTests {
  private let helper = "$HOME/Library/Application Support/Multishell/bin/multishell"

  @Test func theCommandRunsTheHelperNamesTheAgentAndExitsCleanlyWithoutIt() {
    let command = AgentHooks.command(agent: "codex", helper: helper)
    #expect(
      command == "[ -x \"\(helper)\" ] && \"\(helper)\" agent-hook --agent codex; exit 0")
    #expect(!command.contains("="), "fish does not parse VAR=value")
    #expect(AgentHooks.isMultishellHook(command))
    #expect(!AgentHooks.isMultishellHook("curl -sf http://127.0.0.1:9/hook"))
  }

  /// Copilot denies a tool call when a preToolUse hook exits non-zero, and
  /// Claude blocks one on exit 2. Whatever becomes of the helper, the line
  /// answers 0: the worst a broken Multishell may do is stop the dots.
  @Test func aHelperThatDiesTakesTheDotsWithItAndNotTheToolCall() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fake = directory.appendingPathComponent("multishell")

    for ending in ["exit 3", "exit 2", "kill -TERM $$"] {
      try "#!/bin/sh\n\(ending)\n".write(to: fake, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
      #expect(
        try status(of: AgentHooks.command(agent: "copilot", helper: fake.path)) == 0, "\(ending)")
    }

    try FileManager.default.removeItem(at: fake)
    #expect(try status(of: AgentHooks.command(agent: "copilot", helper: fake.path)) == 0, "missing")
  }

  /// Runs the hook line the way an agent would, and answers with its status.
  private func status(of line: String) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", line]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
  }

  /// The first hooks were installed with `claude-hook`, and settings files
  /// still say it: an install that did not recognise its own line would
  /// append a second one beside it.
  @Test func theLineAnOlderBuildWroteIsStillOurs() {
    let old = "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
    #expect(AgentHooks.isMultishellHook(old))
    #expect(AgentHooks.claude.isInstalled(in: ["hooks": groups(claudeEvents, command: old)]))
  }

  @Test func everyIntegrationIsAnAgentTheCatalogueKnows() {
    for integration in AgentHooks.integrations {
      #expect(AgentCatalogue.agent(integration.id) != nil, "\(integration.id) is not launchable")
      #expect(AgentHooks.integration(for: integration.id)?.name == integration.name)
    }
    #expect(AgentHooks.integration(for: "aider") == nil)
    #expect(
      AgentHooks.integrations.map(\.id) == ["claude", "codex", "gemini", "copilot", "opencode"])
  }

  @Test func everyHookedEventGetsOneEntryAndTheSnippetIsValidJSON() throws {
    let entries = AgentHooks.claude.entries(helper: helper)
    let hooks = try #require(entries["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(AgentHooks.claude.events.map(\.name)))
    #expect(AgentHooks.claude.isInstalled(in: entries))

    let snippet = AgentHooks.claude.snippet(helper: helper)
    let parsed = try JSONSerialization.jsonObject(with: Data(snippet.utf8)) as? [String: Any]
    #expect(AgentHooks.claude.isInstalled(in: parsed ?? [:]))
    #expect(snippet.contains("\"timeout\" : 5"))
  }

  /// Gemini counts the timeout in milliseconds, and five seconds spelled as
  /// five would kill the helper before it reached the socket.
  @Test func geminiCountsTheTimeoutInMilliseconds() throws {
    #expect(AgentHooks.gemini.snippet(helper: helper).contains("\"timeout\" : 5000"))
    #expect(AgentHooks.claude.snippet(helper: helper).contains("\"timeout\" : 5"))
    #expect(AgentHooks.codex.snippet(helper: helper).contains("\"timeout\" : 5"))
  }

  @Test func addingLeavesOtherHooksAndOtherSettingsAlone() throws {
    let existing: [String: Any] = [
      "model": "opus",
      "permissions": ["allow": ["Bash(git *)"]],
      "hooks": [
        "Notification": [
          ["hooks": [["type": "command", "command": "curl -sf http://127.0.0.1:9/hook"]]]
        ],
        "PreCompact": [["hooks": [["type": "command", "command": "echo compacting"]]]],
      ],
    ]
    #expect(!AgentHooks.claude.isInstalled(in: existing))

    let added = AgentHooks.claude.adding(to: existing, helper: helper)

    #expect(AgentHooks.claude.isInstalled(in: added))
    #expect(added["model"] as? String == "opus")
    #expect((added["permissions"] as? [String: Any])?["allow"] as? [String] == ["Bash(git *)"])
    let hooks = try #require(added["hooks"] as? [String: Any])
    let notification = try #require(hooks["Notification"] as? [[String: Any]])
    #expect(notification.count == 2, "the curl hook stays, ours is appended")
    #expect(command(of: notification[0]).hasPrefix("curl"))
    #expect(AgentHooks.isMultishellHook(command(of: notification[1])))
    #expect((hooks["PreCompact"] as? [[String: Any]])?.count == 1, "an event we do not hook")

    let twice = AgentHooks.claude.adding(to: added, helper: helper)
    #expect(
      (try #require(twice["hooks"] as? [String: Any])["Stop"] as? [[String: Any]])?.count == 1,
      "adding again adds nothing")
  }

  /// Two agents can share neither a file nor an event name, but the same
  /// settings shape: removing one must not take the other's line.
  @Test func removingTakesOnlyOursAndDropsEmptiedEvents() throws {
    let existing: [String: Any] = [
      "hooks": [
        "Notification": [
          ["hooks": [["type": "command", "command": "curl -sf http://127.0.0.1:9/hook"]]]
        ]
      ]
    ]
    let removed = AgentHooks.claude.removing(
      from: AgentHooks.claude.adding(to: existing, helper: helper))

    let hooks = try #require(removed["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == ["Notification"], "Stop and the rest held only ours")
    #expect((hooks["Notification"] as? [[String: Any]])?.count == 1)
    #expect(!AgentHooks.claude.isInstalled(in: removed))

    let bare = AgentHooks.claude.removing(from: AgentHooks.claude.adding(to: [:], helper: helper))
    #expect(bare["hooks"] == nil, "no hooks left means no hooks key")
  }

  /// Whatever is under an event this cannot read is the user's: a string
  /// where a list of hooks goes, an object, a shape a later version of the
  /// agent takes. Remove must not carry it off, and Add must not write over
  /// it — nothing there was ever ours.
  @Test func anEntryThisCannotReadIsLeftToTheUser() throws {
    let existing: [String: Any] = [
      "hooks": [
        "Stop": ["echo done"],
        "PreToolUse": ["command": "echo before"],
        "Notification": [["hooks": [["type": "command", "command": "say hi"]]]],
      ]
    ]

    let removed = AgentHooks.claude.removing(from: existing)
    let afterRemove = try #require(removed["hooks"] as? [String: Any])
    #expect(afterRemove["Stop"] as? [String] == ["echo done"], "a string list is not ours to drop")
    #expect(
      (afterRemove["PreToolUse"] as? [String: Any])?["command"] as? String == "echo before",
      "nor is an object")
    #expect((afterRemove["Notification"] as? [[String: Any]])?.count == 1, "and the readable stays")

    let added = AgentHooks.claude.adding(to: existing, helper: helper)
    let afterAdd = try #require(added["hooks"] as? [String: Any])
    #expect(afterAdd["Stop"] as? [String] == ["echo done"], "not written over either")
    #expect((afterAdd["PreToolUse"] as? [String: Any])?["command"] as? String == "echo before")
    #expect((afterAdd["Notification"] as? [[String: Any]])?.count == 2, "ours joins the readable")
  }

  /// Leaving it alone in silence would leave a row that never says
  /// Installed, so the install refuses and names the event.
  @Test func installingRefusesAFileWhoseEntriesItCannotRead() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    let original = #"{"hooks":{"Stop":"echo done"}}"#
    try original.write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnreadableHookEntries.self) {
      try AgentHooks.claude.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == original, "not a byte written")
    #expect(!AgentHooks.claude.isInstalled(in: file))
    #expect(AgentHooks.claude.unreadableEvents(in: try HookSettingsFile.read(file)) == ["Stop"])
  }

  @Test func installingIntoAFileCreatesItKeepsABackupAndIsIdempotent() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent(".claude/settings.json")
    let claude = AgentHooks.claude

    #expect(!claude.isInstalled(in: file))
    try claude.install(into: file, helper: helper)
    #expect(claude.isInstalled(in: file))
    #expect(
      !FileManager.default.fileExists(
        atPath: file.appendingPathExtension("before-multishell").path),
      "nothing to back up when the file did not exist")

    // A hand-edited file with other content gets a backup once.
    try #"{ "model": "opus", "hooks": {} }"#.write(to: file, atomically: true, encoding: .utf8)
    try claude.install(into: file, helper: helper)
    let backup = file.appendingPathExtension("before-multishell")
    #expect(try String(contentsOf: backup, encoding: .utf8).contains("\"model\": \"opus\""))
    let written = try HookSettingsFile.read(file)
    #expect(written["model"] as? String == "opus")
    #expect(claude.isInstalled(in: written))

    try claude.install(into: file, helper: helper)
    #expect(
      try String(contentsOf: backup, encoding: .utf8).contains("\"hooks\": {}"),
      "the backup is the pre-Multishell file, not overwritten by a later install")

    try claude.remove(from: file)
    #expect(!claude.isInstalled(in: file))
    #expect(try HookSettingsFile.read(file)["model"] as? String == "opus")
  }

  @Test func aFileThatIsNotAnObjectIsRefusedNotRewritten() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("settings.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try "[1, 2, 3]".write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnexpectedSettingsShape.self) {
      try AgentHooks.gemini.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == "[1, 2, 3]")
    #expect(!AgentHooks.gemini.isInstalled(in: file))
  }

  /// Gemini's settings file takes comments, and Gemini keeps them when it
  /// writes the file itself. Reading one loosely and writing it back
  /// strictly would throw them away, so the file is left alone.
  @Test func aFileWithCommentsIsRefusedRatherThanRewrittenWithoutThem() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    let commented = """
      {
        // the model I use everywhere
        "theme": "Default",
        "hooks": {}
      }
      """
    try commented.write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnparsableSettingsFile.self) {
      try AgentHooks.gemini.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == commented, "comments and all")
    #expect(!AgentHooks.gemini.isInstalled(in: file))
    #expect(
      !FileManager.default.fileExists(
        atPath: file.appendingPathExtension("before-multishell").path),
      "nothing was written, so nothing was backed up")
  }

  /// A settings file is often a symlink into a dotfiles repository. An
  /// atomic write puts a regular file where the link was, and the
  /// repository stops seeing the user's settings from then on.
  @Test func aSymlinkedSettingsFileIsWrittenThroughRatherThanReplaced() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let dotfiles = directory.appendingPathComponent("dotfiles", isDirectory: true)
    let home = directory.appendingPathComponent("home/.claude", isDirectory: true)
    try FileManager.default.createDirectory(at: dotfiles, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    let tracked = dotfiles.appendingPathComponent("settings.json")
    try #"{ "model": "opus" }"#.write(to: tracked, atomically: true, encoding: .utf8)
    let link = home.appendingPathComponent("settings.json")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tracked)

    try AgentHooks.claude.install(into: link, helper: helper)

    #expect(
      (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == tracked.path,
      "still a link, so the dotfiles repository still owns the file")
    #expect(AgentHooks.claude.isInstalled(in: tracked), "written through to what it points at")
    #expect(try HookSettingsFile.read(tracked)["model"] as? String == "opus")

    // The copy goes beside the link, where the user will look for it, not
    // into the repository the link points into.
    #expect(
      try String(contentsOf: link.appendingPathExtension("before-multishell"), encoding: .utf8)
        .contains("opus"))
    #expect(
      !FileManager.default.fileExists(
        atPath: tracked.appendingPathExtension("before-multishell").path),
      "nothing new in the dotfiles repository for git to report")

    try AgentHooks.claude.remove(from: link)
    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) != nil)
    #expect(!AgentHooks.claude.isInstalled(in: tracked))
  }

  @Test func anEmptyFileReadsAsNoSettings() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    try "\n".write(to: file, atomically: true, encoding: .utf8)
    #expect(try HookSettingsFile.read(file).isEmpty)
  }

  /// Copilot reads every JSON file in its hooks directory, so ours is a
  /// file of its own: one flat list of hooks per event, and a version.
  @Test func copilotGetsAFileOfItsOwnWrittenWholeAndDeletedToRemoveIt() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("hooks/multishell.json")
    let copilot = AgentHooks.copilot

    try copilot.install(into: file, helper: helper)
    let written =
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any] ?? [:]
    #expect(written["version"] as? Int == 1)
    let hooks = try #require(written["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(copilot.events.map(\.name)))
    let stop = try #require(hooks["Stop"] as? [[String: Any]])
    #expect(stop.count == 1, "a hook on its own, not a group of them")
    #expect(AgentHooks.isMultishellHook(stop[0]["command"] as? String ?? ""))
    #expect(stop[0]["timeoutSec"] as? Int == 5, "Copilot counts it under its own key")
    #expect(copilot.isInstalled(in: file))

    try copilot.remove(from: file)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(!copilot.isInstalled(in: file))
  }

  /// The name is ours; the file on disk decides. Removing must not delete
  /// something else that happens to be called that.
  @Test func aFileOfOursThatIsNotOursIsLeftWhereItIs() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("multishell.json")
    try #"{"version":1,"hooks":{}}"#.write(to: file, atomically: true, encoding: .utf8)

    #expect(!AgentHooks.copilot.isInstalled(in: file))
    try AgentHooks.copilot.remove(from: file)
    #expect(FileManager.default.fileExists(atPath: file.path))
  }

  /// OpenCode reports nothing to a hook command, so it is given a plugin
  /// that calls the helper itself, with the states spelled as the helper
  /// takes them.
  @Test func openCodeGetsAPluginThatCallsTheHelper() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("plugin/multishell.js")
    let openCode = AgentHooks.openCode

    try openCode.install(into: file, helper: helper)
    let source = try String(contentsOf: file, encoding: .utf8)
    #expect(
      source.contains("homedir() + \"/Library/Application Support/Multishell/bin/multishell\""))
    #expect(source.contains("\"state\", state, \"--agent\", \"opencode\""))
    for state in [SessionState.running, .attention, .done, .error] {
      #expect(source.contains("report(\"\(state.rawValue)\""), "no \(state.rawValue)")
    }
    #expect(source.contains("session.idle"))
    #expect(source.contains("permission.asked"), "the hook of that name is never called")
    #expect(source.contains("permission.replied"), "the one agent that says the answer came")
    #expect(
      !source.contains("\"permission.ask\":"),
      "listening on both would report one prompt twice")
    #expect(openCode.isInstalled(in: file))
    #expect(openCode.entries(helper: helper).isEmpty, "a plugin is not a hooks object")

    try openCode.remove(from: file)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test func theHelperReferenceGoesThroughHOME() {
    let reference = AgentHooks.helperReference
    #expect(
      reference.hasPrefix("$HOME/")
        || !reference.contains(FileManager.default.homeDirectoryForCurrentUser.path))
    #expect(reference.hasSuffix("/bin/multishell"))
  }

  private var claudeEvents: [String] { AgentHooks.claude.events.map(\.name) }

  private func groups(_ events: [String], command: String) -> [String: Any] {
    var hooks: [String: Any] = [:]
    for event in events {
      hooks[event] = [["hooks": [["type": "command", "command": command]]]]
    }
    return hooks
  }

  private func command(of group: [String: Any]) -> String {
    ((group["hooks"] as? [[String: Any]])?.first?["command"] as? String) ?? ""
  }

  private func temporaryDirectory() -> URL {
    Scratch.path("hooks")
  }
}

@Suite
struct AgentCatalogueTests {
  @Test func theOverrideBeatsTheGlobalAndNoneMeansNoAgent() {
    #expect(AgentCatalogue.effectiveID(global: "claude", override: nil) == "claude")
    #expect(AgentCatalogue.effectiveID(global: "claude", override: "codex") == "codex")
    #expect(AgentCatalogue.effectiveID(global: "claude", override: "none") == nil)
    #expect(AgentCatalogue.effectiveID(global: nil, override: nil) == nil)
    #expect(AgentCatalogue.effectiveID(global: "none", override: nil) == nil)
    #expect(AgentCatalogue.effectiveID(global: "", override: nil) == nil)
    #expect(AgentCatalogue.effectiveID(global: nil, override: "aider") == "aider")
  }

  /// Each of the five the app supports first-hand resumes the way its own
  /// CLI spells it; one spelled wrong reaches the pane as "unknown option"
  /// and the tab is a shell where a conversation was expected.
  @Test func theSupportedAgentsResumeTheirLastConversation() {
    let resume = { AgentCatalogue.agent($0)?.resumeArguments }
    #expect(resume("claude") == ["--continue"])
    #expect(resume("codex") == ["resume", "--last"])
    #expect(resume("gemini") == ["--resume", "latest"])
    #expect(resume("copilot") == ["--continue"])
    #expect(resume("opencode") == ["--continue"])
    #expect(resume("aider") == nil, "no flag for it, so a saved tab is a shell")
  }

  @Test func idsAreUniqueAndReserved() {
    let ids = AgentCatalogue.agents.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(!ids.contains(AgentCatalogue.noneID) && !ids.contains(AgentCatalogue.customID))
    #expect(AgentCatalogue.agent("claude")?.resumeArguments == ["--continue"])
    #expect(AgentCatalogue.agent("wezterm-agent") == nil)
  }

  @Test func aWorkspaceResolvesAProjectsAgent() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    let follows = Project(path: URL(fileURLWithPath: "/a"))
    let optsOut = Project(
      path: URL(fileURLWithPath: "/b"), settings: ProjectSettings(preferredAgentID: "none"))
    let overrides = Project(
      path: URL(fileURLWithPath: "/c"), settings: ProjectSettings(preferredAgentID: "codex"))
    #expect(workspace.preferredAgentID(for: follows) == "claude")
    #expect(workspace.preferredAgentID(for: optsOut) == nil)
    #expect(workspace.preferredAgentID(for: overrides) == "codex")
  }

  @Test func autoStartFollowsTheGlobalUnlessOverriddenAndNeedsAnAgent() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    let follows = Project(path: URL(fileURLWithPath: "/a"))
    let forcedOn = Project(
      path: URL(fileURLWithPath: "/b"), settings: ProjectSettings(autoStartAgent: true))
    let forcedOff = Project(
      path: URL(fileURLWithPath: "/c"), settings: ProjectSettings(autoStartAgent: false))
    let noAgent = Project(
      path: URL(fileURLWithPath: "/d"),
      settings: ProjectSettings(preferredAgentID: "none", autoStartAgent: true))

    #expect(!workspace.autoStartsAgent(for: follows), "global off")
    #expect(workspace.autoStartsAgent(for: forcedOn))
    #expect(!workspace.autoStartsAgent(for: noAgent), "nothing to start")

    workspace.autoStartAgent = true
    #expect(workspace.autoStartsAgent(for: follows))
    #expect(!workspace.autoStartsAgent(for: forcedOff))
  }

  @Test func autoStartOnCreationIsAskedApartFromAutoStartOnTabOpen() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    workspace.autoStartAgentOnCreate = true
    let follows = Project(path: URL(fileURLWithPath: "/a"))
    let forcedOff = Project(
      path: URL(fileURLWithPath: "/b"), settings: ProjectSettings(autoStartAgentOnCreate: false))
    let noAgent = Project(
      path: URL(fileURLWithPath: "/c"), settings: ProjectSettings(preferredAgentID: "none"))

    #expect(workspace.autoStartsAgentOnCreate(for: follows))
    #expect(!workspace.autoStartsAgent(for: follows), "the tab-open setting is still off")
    #expect(!workspace.autoStartsAgentOnCreate(for: forcedOff))
    #expect(!workspace.autoStartsAgentOnCreate(for: noAgent), "nothing to start")
  }
}

/// Settings files built at random, put through Add and Remove: what was in
/// the file has to come back, since the one promise these make is that they
/// touch nothing they did not write. A failure prints the seed.
@Suite
struct AgentHookMergeInvariantTests {
  private let helper = "$HOME/Library/Application Support/Multishell/bin/multishell"

  @Test(arguments: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89] as [UInt64])
  func addAndRemoveGiveBackTheFileTheyWereGiven(seed: UInt64) throws {
    var rng = SeededGenerator(seed: seed)
    for integration in AgentHooks.integrations where !integration.isOursAlone {
      let before = settings(&rng, events: integration.events.map(\.name))
      let unreadable = integration.unreadableEvents(in: before)

      let added = integration.adding(to: before, helper: helper)
      #expect(
        integration.isInstalled(in: added) == unreadable.isEmpty,
        "seed \(seed) \(integration.id): installed unless an entry was unreadable")
      #expect(
        integration.adding(to: added, helper: helper).keys.count == added.keys.count,
        "seed \(seed) \(integration.id): adding twice adds nothing")

      let after = integration.removing(from: added)
      #expect(
        foreign(in: after) == foreign(in: before),
        "seed \(seed) \(integration.id): a hook of the user's did not come back")
      #expect(
        !integration.isInstalled(in: after) || integration.events.isEmpty,
        "seed \(seed) \(integration.id): ours did not all come out")
      for (key, value) in before where key != "hooks" {
        #expect(
          String(describing: after[key] ?? "") == String(describing: value),
          "seed \(seed) \(integration.id): \(key) was not left alone")
      }
    }
  }

  /// Every hook in the file that is not ours, by the command it runs, plus
  /// whatever sits under an event in a shape these do not write.
  private func foreign(in settings: [String: Any]) -> Set<String> {
    var found: Set<String> = []
    for (event, value) in settings["hooks"] as? [String: Any] ?? [:] {
      guard let groups = value as? [[String: Any]] else {
        found.insert("\(event)=\(String(describing: value))")
        continue
      }
      for group in groups {
        let commands = (group["hooks"] as? [[String: Any]] ?? []).compactMap {
          $0["command"] as? String
        }
        for command in commands where !AgentHooks.isMultishellHook(command) {
          found.insert("\(event)=\(command)")
        }
      }
    }
    return found
  }

  /// A settings file with the shapes these meet: keys of the user's own, a
  /// hooks object holding foreign hooks, ours from an older build, entries
  /// in a shape this cannot read, and events left out altogether.
  private func settings(
    _ rng: inout SeededGenerator, events: [String]
  ) -> [String: Any] {
    var hooks: [String: Any] = [:]
    for event in events + ["PreCompact", "SomethingLater"] {
      switch Int.random(in: 0...5, using: &rng) {
      case 0: break
      case 1: hooks[event] = []
      case 2:
        hooks[event] = [["hooks": [["type": "command", "command": "echo \(event)"]]]]
      case 3:
        let old = "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
        hooks[event] = [["hooks": [["type": "command", "command": old]]]]
      case 4: hooks[event] = "echo \(event)"
      default: hooks[event] = ["command": "echo \(event)"]
      }
    }
    var settings: [String: Any] = ["hooks": hooks]
    if Bool.random(using: &rng) { settings["model"] = "opus" }
    if Bool.random(using: &rng) { settings["permissions"] = ["allow": ["Bash(git *)"]] }
    return settings
  }
}
