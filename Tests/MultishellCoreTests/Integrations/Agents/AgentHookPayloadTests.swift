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
    let claude = AgentHookCatalogue.claude
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
    #expect(claude.events.first { $0.name == "SubagentStart" }?.subagentPhase == .started)
    #expect(claude.events.first { $0.name == "SubagentStop" }?.subagentPhase == .ended)
    #expect(
      claude.events.filter { $0.subagentPhase != nil }.count == 2,
      "one event each way, or a worker never leaves the roster")
    // Ctrl+C fires no hook and the workers it killed send no stop, so the
    // next prompt is what empties the roster.
    #expect(claude.events.first { $0.name == "UserPromptSubmit" }?.isTurnStart == true)
    #expect(claude.events.filter(\.isTurnStart).count == 1)
    #expect(
      AgentHookCatalogue.codex.events.first { $0.name == "UserPromptSubmit" }?.isTurnStart == true)
    #expect(
      AgentHookCatalogue.copilot.events.first { $0.name == "UserPromptSubmit" }?.isTurnStart == true
    )
    #expect(
      AgentHookCatalogue.gemini.events.first { $0.name == "BeforeAgent" }?.isTurnStart == true)
    #expect(state(claude, "PostToolUseFailure") == nil, "a tool failing is not a turn failing")
    #expect(state(claude, "PreCompact") == nil)
    #expect(state(claude, "PostCompact") == nil, "it fires when the compaction is over")
    #expect(state(claude, "SomethingNew") == nil)

    let codex = AgentHookCatalogue.codex
    #expect(state(codex, "PermissionRequest") == .attention, "Codex's own Notification")
    #expect(state(codex, "Stop") == .done)
    #expect(state(codex, "Interrupt") == .idle, "the turn ended, nothing finished")
    #expect(state(codex, "Notification") == nil, "an event Codex does not have")

    let gemini = AgentHookCatalogue.gemini
    #expect(state(gemini, "BeforeAgent") == .running)
    #expect(state(gemini, "BeforeTool") == .running)
    #expect(state(gemini, "AfterAgent") == .done)
    #expect(state(gemini, "Notification") == .attention)
    #expect(state(gemini, "Stop") == nil, "Gemini names its own events")
  }

  /// Codex asks its hook before deciding a call needs anyone, so under a mode that never
  /// stops a request is work, and a banner would land on every full-auto tool call.
  @Test func codexOnlyWaitsInAModeThatStopsForTheUser() {
    let codex = AgentHookCatalogue.codex
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

  /// Claude, like Codex, asks the hook before deciding a call needs anyone, so the mode
  /// governs the request; its `auto` is the mode a classifier answers in.
  @Test func claudeOnlyWaitsOnARequestInAModeThatStopsForTheUser() {
    let claude = AgentHookCatalogue.claude
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
    let claude = AgentHookCatalogue.claude
    let request = try #require(claude.event(for: AgentHookPayload(eventName: "PermissionRequest")))
    let notification = try #require(claude.event(for: AgentHookPayload(eventName: "Notification")))
    #expect(request.state == notification.state)
    #expect(request.silent)
    #expect(!notification.silent)
    #expect(claude.events.filter(\.silent).count == 1)
    #expect(AgentHookCatalogue.integrations.allSatisfy { $0.events.filter(\.silent).count <= 1 })
  }

  /// Claude notifies for a finished login or a resumed quota as for a question, and the
  /// idle one a minute after a turn follows the Done its Stop already reported.
  @Test func claudeOnlyWaitsOnANotificationThatAsksSomething() {
    let claude = AgentHookCatalogue.claude
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
    for announcement in [
      "computer_use_enter", "computer_use_exit", "elicitation_complete", "elicitation_response",
      "push_notification",
    ] {
      #expect(state(announcement) == nil, "\(announcement)")
    }
    #expect(state("quota_auto_resume_stale") == .attention, "it asks for Return")
    #expect(state("quota_auto_resume_disabled") == .attention, "it asks for a prompt")
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
      AgentHookCatalogue.integrations.filter { $0.id != AgentCatalogue.claudeID }
        .allSatisfy { $0.events.allSatisfy(\.ignoredNotificationTypes.isEmpty) },
      "Claude is the only agent whose payload names a type")
  }

  /// Copilot takes `notification` in its file and reports `Notification`;
  /// a hook that read one name for the other would map nothing.
  @Test func copilotIsAskedByOneNameAndReportsByAnother() throws {
    let copilot = AgentHookCatalogue.copilot
    let event = try #require(copilot.events.first { $0.state == .attention })
    #expect(event.name == "notification")
    #expect(event.reportedName == "Notification")
    #expect(state(copilot, "Notification") == .attention)
    #expect(state(copilot, "notification") == nil, "what the payload says decides")
    #expect(state(copilot, "Stop") == .done)
  }

  /// Copilot notifies for a finished background shell as for a question, so the file asks
  /// for the question types by matcher rather than this code sorting them.
  @Test func copilotAsksOnlyForTheNotificationsThatAreQuestions() throws {
    let event = try #require(AgentHookCatalogue.copilot.events.first { $0.state == .attention })
    #expect(event.matcher == "permission_prompt|elicitation_dialog")
    #expect(
      AgentHookCatalogue.copilot.events.allSatisfy { $0.state == .attention || $0.matcher == nil },
      "nothing else needs filtering")
    #expect(
      AgentHookCatalogue.gemini.events.allSatisfy { $0.matcher == nil },
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
    #expect(AgentHookCatalogue.claude.event(for: try #require(payload))?.state == .attention)
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

  @Test func codexNamesASubagentAsClaudeDoes() throws {
    let codex = AgentHookCatalogue.codex
    #expect(codex.events.first { $0.name == "SubagentStart" }?.subagentPhase == .started)
    #expect(codex.events.first { $0.name == "SubagentStop" }?.subagentPhase == .ended)
    let inCodex = try #require(
      AgentHookPayload(
        json: Data(
          #"{"hook_event_name":"PreToolUse","agent_id":"t2","agent_type":"worker","tool_name":"shell"}"#
            .utf8)))
    #expect(
      codex.event(for: inCodex)?.subagentChange(for: inCodex)
        == SubagentReport(id: "t2", type: "worker", phase: .working))
    #expect(
      AgentHookCatalogue.gemini.events.allSatisfy { $0.subagentPhase == nil },
      "Gemini says nothing about a subagent to a hook")
  }

  /// Captured from Copilot 1.0.87: a subagent is a conversation of its own,
  /// its Stop filed under its parent's transcript, and its end names it.
  @Test func copilotNamesASubagentByItsConversation() throws {
    let copilot = AgentHookCatalogue.copilot
    let parent = "17954dff-e162-4e7a-925e-a59ca530c5fb"
    let child = "37880ecf-c5f3-42ce-afe0-82b221d75839"
    let transcript = "/Users/dev/.copilot/session-state/\(parent)/events.jsonl"
    func payload(_ json: String) throws -> AgentHookPayload {
      try #require(AgentHookPayload(json: Data(json.utf8)))
    }

    let childStop = try payload(
      #"{"hook_event_name":"Stop","session_id":"\#(child)","transcript_path":"\#(transcript)"}"#)
    #expect(copilot.event(for: childStop) == nil)
    let ownStop = try payload(
      #"{"hook_event_name":"Stop","session_id":"\#(parent)","transcript_path":"\#(transcript)"}"#)
    #expect(copilot.event(for: ownStop)?.state == .done)
    let fileNamedForItself = try payload(
      #"{"hook_event_name":"Stop","session_id":"\#(parent)","transcript_path":"/Users/dev/.copilot/session-state/\#(parent).jsonl"}"#
    )
    #expect(
      copilot.event(for: fileNamedForItself)?.state == .done,
      "a transcript naming the conversation anywhere is its own")
    #expect(
      AgentHookCatalogue.claude.event(for: childStop)?.state == .done,
      "only an agent that runs workers as conversations is read this way")

    let childTool = try payload(
      #"{"hook_event_name":"PreToolUse","session_id":"\#(child)","tool_name":"Bash"}"#)
    #expect(
      copilot.report(for: childTool, session: nil, cwd: nil, pid: nil)?.conversationID == child)
    #expect(
      AgentHookCatalogue.claude.report(for: childTool, session: nil, cwd: nil, pid: nil)?
        .conversationID
        == nil)

    let end = try payload(
      #"{"hook_event_name":"SubagentStop","session_id":"\#(parent)","transcript_path":"\#(transcript)","agent_id":"\#(child)","agent_type":"general-purpose","agent_name":"general-purpose"}"#
    )
    #expect(
      copilot.event(for: end)?.subagentChange(for: end)
        == SubagentReport(id: child, type: "general-purpose", phase: .ended))
    #expect(
      !copilot.events.contains { $0.name == "SubagentStart" },
      "its start names no id, and arrives in a spelling no event is read in")
  }

  @Test func aPayloadWithoutAnEventNameIsNotAPayload() {
    #expect(AgentHookPayload(json: Data(#"{"cwd":"/w"}"#.utf8)) == nil)
    #expect(AgentHookPayload(json: Data("nope".utf8)) == nil)
    #expect(AgentHookPayload(json: Data()) == nil)
  }
}
