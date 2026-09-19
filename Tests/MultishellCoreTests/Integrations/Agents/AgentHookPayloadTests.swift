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
    // Asked for so the roster can be kept: `Stop` is the main loop stopping,
    // which happens while these are still going. What they move is the roster.
    #expect(state(claude, "SubagentStart") == .running)
    #expect(state(claude, "SubagentStop") == .running, "the agent is still working")
    #expect(claude.events.first { $0.name == "SubagentStart" }?.subagent == .started)
    #expect(claude.events.first { $0.name == "SubagentStop" }?.subagent == .ended)
    #expect(
      claude.events.filter { $0.subagent != nil }.count == 2,
      "one event each way, or a worker never leaves the roster")
    // Ctrl+C fires no hook and the workers it killed send no stop, so the
    // next prompt is what empties the roster.
    #expect(claude.events.first { $0.name == "UserPromptSubmit" }?.startsTurn == true)
    #expect(claude.events.filter(\.startsTurn).count == 1)
    #expect(AgentHooks.codex.events.first { $0.name == "UserPromptSubmit" }?.startsTurn == true)
    #expect(AgentHooks.copilot.events.first { $0.name == "UserPromptSubmit" }?.startsTurn == true)
    #expect(AgentHooks.gemini.events.first { $0.name == "BeforeAgent" }?.startsTurn == true)
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
      "a blue dot too early beats one that never comes")
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

  /// Claude raises a notification for a finished login and a resumed
  /// quota as much as for a question, and the idle one a minute after a
  /// turn ends followed the Done that turn's Stop had already reported.
  @Test func claudeOnlyWaitsOnANotificationThatAsksSomething() {
    let claude = AgentHooks.claude
    func state(_ type: String?) -> SessionState? {
      claude.event(for: AgentHookPayload(eventName: "Notification", notificationType: type))?.state
    }
    #expect(state("permission_prompt") == .attention)
    #expect(state("worker_permission_prompt") == .attention)
    #expect(state("elicitation_dialog") == .attention)
    #expect(state("agent_needs_input") == .attention)
    #expect(state("idle_prompt") == nil, "the Stop of that turn already said Done")
    #expect(state("agent_completed") == nil)
    #expect(state("auth_success") == nil)
    #expect(state("quota_auto_resume_fired") == nil)
    #expect(state(nil) == .attention, "a Claude from before the field keeps its banner")
    #expect(
      state("plan_approval_prompt") == .attention,
      "a type this build has not heard of is taken to ask; see Docs/design/agents.md")
    #expect(
      claude.event(for: AgentHookPayload(eventName: "Stop", notificationType: "idle_prompt"))?
        .state == .done, "the types govern that event only")
    #expect(
      claude.events.allSatisfy { $0.state == .attention || $0.ignoredNotificationTypes.isEmpty },
      "no event but a question is filtered by type")
    #expect(
      AgentHooks.integrations.filter { $0.id != AgentCatalogue.claudeID }
        .allSatisfy { $0.events.allSatisfy(\.ignoredNotificationTypes.isEmpty) },
      "Claude is the only agent whose payload names a type")
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
  /// much as for a question, and only the questions are worth a blue
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

  @Test func theStdinPayloadYieldsEventDirectoryAndMessage() throws {
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
    #expect(payload?.notificationType == "permission_prompt")
    #expect(AgentHooks.claude.event(for: try #require(payload))?.state == .attention)
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

  /// Codex spells a subagent as Claude does. Copilot names one at its start and
  /// adds an id only at its stop, so the name is the key at both ends.
  @Test func codexAndCopilotNameASubagentInTheirOwnSpelling() throws {
    let codex = AgentHooks.codex
    #expect(codex.events.first { $0.name == "SubagentStart" }?.subagent == .started)
    #expect(codex.events.first { $0.name == "SubagentStop" }?.subagent == .ended)
    let inCodex = try #require(
      AgentHookPayload(
        json: Data(
          #"{"hook_event_name":"PreToolUse","agent_id":"t2","agent_type":"worker","tool_name":"shell"}"#
            .utf8)))
    #expect(
      codex.event(for: inCodex)?.subagentReport(for: inCodex)
        == SubagentReport(id: "t2", type: "worker", phase: .working))

    let copilot = AgentHooks.copilot
    let start = try #require(
      AgentHookPayload(
        json: Data(
          #"""
          {"hook_event_name":"SubagentStart","sessionId":"s","timestamp":1,"cwd":"/w",
           "agentName":"code-review","agentDisplayName":"Code Review"}
          """#.utf8)))
    #expect(
      copilot.event(for: start)?.subagentReport(for: start)
        == SubagentReport(id: "code-review", type: "Code Review", phase: .started))
    let stop = try #require(
      AgentHookPayload(
        json: Data(
          #"""
          {"hook_event_name":"SubagentStop","sessionId":"s","timestamp":2,"cwd":"/w",
           "agentId":"a9","agentType":"custom","agentName":"code-review","stopReason":"end_turn"}
          """#.utf8)))
    #expect(
      copilot.event(for: stop)?.subagentReport(for: stop)?.id == "code-review",
      "the stop's id was never seen at the start; the name was")
    #expect(copilot.event(for: stop)?.subagentReport(for: stop)?.phase == .ended)
    // A session run under --agent may name that agent on every event; a
    // name on a tool call is not a worker, or the roster never empties.
    let underAgent = try #require(
      AgentHookPayload(
        json: Data(
          #"{"hook_event_name":"PreToolUse","sessionId":"s","cwd":"/w","agentName":"reviewer"}"#
            .utf8)))
    #expect(copilot.event(for: underAgent)?.subagentReport(for: underAgent) == nil)
    #expect(
      AgentHooks.gemini.events.allSatisfy { $0.subagent == nil },
      "Gemini says nothing about a subagent to a hook")
  }

  @Test func aPayloadWithoutAnEventNameIsNotAPayload() {
    #expect(AgentHookPayload(json: Data(#"{"cwd":"/w"}"#.utf8)) == nil)
    #expect(AgentHookPayload(json: Data("nope".utf8)) == nil)
    #expect(AgentHookPayload(json: Data()) == nil)
  }
}
