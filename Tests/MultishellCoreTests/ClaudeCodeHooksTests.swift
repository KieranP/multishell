import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ClaudeHookPayloadTests {
  @Test func eachHookEventMapsToTheStateItStandsFor() {
    #expect(ClaudeHookPayload.state(forEvent: "UserPromptSubmit") == .running)
    #expect(ClaudeHookPayload.state(forEvent: "PreToolUse") == .running)
    #expect(ClaudeHookPayload.state(forEvent: "PostToolUse") == .running)
    #expect(ClaudeHookPayload.state(forEvent: "Notification") == .attention)
    #expect(ClaudeHookPayload.state(forEvent: "Stop") == .done)
    #expect(ClaudeHookPayload.state(forEvent: "StopFailure") == .error)
    #expect(ClaudeHookPayload.state(forEvent: "SessionEnd") == .idle)
    #expect(ClaudeHookPayload.state(forEvent: "SessionStart") == .idle)
    #expect(ClaudeHookPayload.state(forEvent: "SubagentStop") == nil, "the agent is still working")
    #expect(ClaudeHookPayload.state(forEvent: "PreCompact") == nil)
    #expect(ClaudeHookPayload.state(forEvent: "SomethingNew") == nil)
  }

  @Test func theStdinPayloadYieldsEventDirectoryAndMessage() {
    let payload = ClaudeHookPayload(
      json: Data(
        #"""
        { "session_id": "abc", "transcript_path": "/t", "cwd": "/w/repo",
          "hook_event_name": "Notification", "message": "Claude needs your permission",
          "notification_type": "permission_prompt" }
        """#.utf8))
    #expect(payload?.eventName == "Notification")
    #expect(payload?.cwd == "/w/repo")
    #expect(payload?.message == "Claude needs your permission")
    #expect(payload?.state == .attention)
  }

  @Test func aPayloadWithoutAnEventNameIsNotAPayload() {
    #expect(ClaudeHookPayload(json: Data(#"{"cwd":"/w"}"#.utf8)) == nil)
    #expect(ClaudeHookPayload(json: Data("nope".utf8)) == nil)
    #expect(ClaudeHookPayload(json: Data()) == nil)
  }
}

@Suite
struct ClaudeCodeHooksTests {
  private let helper = "$HOME/Library/Application Support/Multishell/bin/multishell"

  @Test func theCommandExecsTheHelperAndExitsCleanlyWithoutIt() {
    let command = ClaudeCodeHooks.command(helper: helper)
    #expect(command == "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0")
    #expect(!command.contains("="), "fish does not parse VAR=value")
    #expect(ClaudeCodeHooks.isMultishellHook(command))
    #expect(!ClaudeCodeHooks.isMultishellHook("curl -sf http://127.0.0.1:9/hook"))
  }

  @Test func everyHookedEventGetsOneEntryAndTheSnippetIsValidJSON() throws {
    let entries = ClaudeCodeHooks.entries(helper: helper)
    let hooks = try #require(entries["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(ClaudeHookPayload.hookedEvents))
    #expect(ClaudeCodeHooks.isInstalled(in: entries))

    let snippet = ClaudeCodeHooks.snippet(helper: helper)
    let parsed = try JSONSerialization.jsonObject(with: Data(snippet.utf8)) as? [String: Any]
    #expect(ClaudeCodeHooks.isInstalled(in: parsed ?? [:]))
    #expect(snippet.contains("\"timeout\" : 5"))
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
    #expect(!ClaudeCodeHooks.isInstalled(in: existing))

    let added = ClaudeCodeHooks.adding(to: existing, helper: helper)

    #expect(ClaudeCodeHooks.isInstalled(in: added))
    #expect(added["model"] as? String == "opus")
    #expect((added["permissions"] as? [String: Any])?["allow"] as? [String] == ["Bash(git *)"])
    let hooks = try #require(added["hooks"] as? [String: Any])
    let notification = try #require(hooks["Notification"] as? [[String: Any]])
    #expect(notification.count == 2, "the curl hook stays, ours is appended")
    #expect(command(of: notification[0]).hasPrefix("curl"))
    #expect(ClaudeCodeHooks.isMultishellHook(command(of: notification[1])))
    #expect((hooks["PreCompact"] as? [[String: Any]])?.count == 1, "an event we do not hook")

    let twice = ClaudeCodeHooks.adding(to: added, helper: helper)
    #expect(
      (try #require(twice["hooks"] as? [String: Any])["Stop"] as? [[String: Any]])?.count == 1,
      "adding again adds nothing")
  }

  @Test func removingTakesOnlyOursAndDropsEmptiedEvents() throws {
    let existing: [String: Any] = [
      "hooks": [
        "Notification": [
          ["hooks": [["type": "command", "command": "curl -sf http://127.0.0.1:9/hook"]]]
        ]
      ]
    ]
    let removed = ClaudeCodeHooks.removing(
      from: ClaudeCodeHooks.adding(to: existing, helper: helper))

    let hooks = try #require(removed["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == ["Notification"], "Stop and the rest held only ours")
    #expect((hooks["Notification"] as? [[String: Any]])?.count == 1)
    #expect(!ClaudeCodeHooks.isInstalled(in: removed))

    let bare = ClaudeCodeHooks.removing(from: ClaudeCodeHooks.adding(to: [:], helper: helper))
    #expect(bare["hooks"] == nil, "no hooks left means no hooks key")
  }

  @Test func installingIntoAFileCreatesItKeepsABackupAndIsIdempotent() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-claude-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent(".claude/settings.json")

    #expect(!ClaudeCodeHooks.isInstalled(in: file))
    try ClaudeCodeHooks.install(into: file, helper: helper)
    #expect(ClaudeCodeHooks.isInstalled(in: file))
    #expect(
      !FileManager.default.fileExists(
        atPath: file.appendingPathExtension("before-multishell").path),
      "nothing to back up when the file did not exist")

    // A hand-edited file with other content gets a backup once.
    try #"{ "model": "opus", "hooks": {} }"#.write(to: file, atomically: true, encoding: .utf8)
    try ClaudeCodeHooks.install(into: file, helper: helper)
    let backup = file.appendingPathExtension("before-multishell")
    #expect(try String(contentsOf: backup, encoding: .utf8).contains("\"model\": \"opus\""))
    let written = try ClaudeCodeHooks.read(file)
    #expect(written["model"] as? String == "opus")
    #expect(ClaudeCodeHooks.isInstalled(in: written))

    try ClaudeCodeHooks.install(into: file, helper: helper)
    #expect(
      try String(contentsOf: backup, encoding: .utf8).contains("\"hooks\": {}"),
      "the backup is the pre-Multishell file, not overwritten by a later install")

    try ClaudeCodeHooks.remove(from: file)
    #expect(!ClaudeCodeHooks.isInstalled(in: file))
    #expect(try ClaudeCodeHooks.read(file)["model"] as? String == "opus")
  }

  @Test func aFileThatIsNotAnObjectIsRefusedNotRewritten() throws {
    let file = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-claude-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    try "[1, 2, 3]".write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnexpectedSettingsShape.self) {
      try ClaudeCodeHooks.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == "[1, 2, 3]")
    #expect(!ClaudeCodeHooks.isInstalled(in: file))
  }

  @Test func anEmptyFileReadsAsNoSettings() throws {
    let file = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-claude-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    try "\n".write(to: file, atomically: true, encoding: .utf8)
    #expect(try ClaudeCodeHooks.read(file).isEmpty)
  }

  @Test func theHelperReferenceGoesThroughHOME() {
    let reference = ClaudeCodeHooks.helperReference
    #expect(
      reference.hasPrefix("$HOME/")
        || !reference.contains(FileManager.default.homeDirectoryForCurrentUser.path))
    #expect(reference.hasSuffix("/bin/multishell"))
  }

  private func command(of group: [String: Any]) -> String {
    ((group["hooks"] as? [[String: Any]])?.first?["command"] as? String) ?? ""
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
}
