import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentHookIntegrationReportsTests: AgentHookFixtures {
  @Test func claudesStopSaysATurnFollowsWhereItsTranscriptHasANoticeQueued() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let transcript = directory.appendingPathComponent("session.jsonl")
    try Data(
      (#"{"type":"queue-operation","operation":"enqueue","timestamp":"2026-09-30T10:00:05.000Z","#
        + #""content":"<task-notification><task-id>a1</task-id>"}"#).utf8
    ).write(to: transcript)
    func follows(_ integration: AgentHookIntegration, _ event: String) -> Bool? {
      let payload = AgentHookPayload(
        json: Data(
          #"{"hook_event_name":"\#(event)","transcript_path":"\#(transcript.path)"}"#.utf8))!
      return integration.report(for: payload, sessionID: nil, cwd: nil, pid: nil)?.turnFollows
    }
    #expect(follows(AgentHookCatalogue.claude, "Stop") == true)
    #expect(follows(AgentHookCatalogue.claude, "PreToolUse") == nil, "only a Stop reads it")
    #expect(follows(AgentHookCatalogue.codex, "Stop") == nil, "Claude's transcript alone")
  }

  @Test func anAgentThatWakesForItsWorkersSaysSoAtItsStop() {
    func resumes(_ integration: AgentHookIntegration, _ event: String) -> Bool? {
      let payload = AgentHookPayload(json: Data(#"{"hook_event_name":"\#(event)"}"#.utf8))!
      return integration.report(for: payload, sessionID: nil, cwd: nil, pid: nil)?
        .resumesAfterWorkers
    }
    #expect(resumes(AgentHookCatalogue.claude, "Stop") == true)
    #expect(resumes(AgentHookCatalogue.copilot, "Stop") == true, "its runtime wakes it")
    #expect(resumes(AgentHookCatalogue.codex, "Stop") == nil, "a child's answer starts no turn")
  }

  @Test func claudesStopListsWhatIsOutShellsIncluded() {
    func stop(_ tasks: String) -> (report: SessionStateReport?, walked: Bool) {
      let payload = AgentHookPayload(
        json: Data(#"{"hook_event_name":"Stop","background_tasks":\#(tasks)}"#.utf8))!
      var walked = false
      let report = AgentHookCatalogue.claude.report(
        for: payload, sessionID: nil, cwd: nil, pid: 7,
        backgroundShells: { _ in
          walked = true
          return [500]
        })
      return (report, walked)
    }
    let subagent =
      #"{"id":"a1","type":"subagent","status":"running","description":"d","agent_type":"Explore"}"#
    let monitor = #"{"id":"m1","type":"monitor","status":"running","description":"d"}"#
    let shell = #"{"id":"b1","type":"shell","status":"running","description":"d","command":"x"}"#
    let dream = #"{"id":"d1","type":"dream","status":"running","description":"dreaming"}"#
    let cloud = #"{"id":"r1","type":"cloud session","status":"running","description":"d"}"#
    let scan = #"{"id":"s1","type":"auto-mode scan","status":"running","description":"d"}"#

    let quiet = stop("[]")
    #expect(quiet.report?.workersOut == [], "nothing out is said, not left unsaid")
    #expect(!quiet.walked)

    let busy = stop("[\(subagent),\(dream),\(monitor),\(scan),\(cloud),\(shell)]")
    #expect(
      busy.report?.workersOut == [
        SubagentReport(id: "a1", type: "Explore", phase: .working),
        SubagentReport(id: "r1", type: "cloud session", phase: .working),
        SubagentReport(id: "b1", phase: .working, isBackgroundShell: true),
      ], "a watcher that never ends and housekeeping ending unannounced hold nothing")
    #expect(!busy.walked, "the list names the shell")
    #expect(busy.report?.backgroundShells == nil)
  }

  /// Claude names the subagent on every event of its own, so each says which
  /// worker it is about; an event naming none is the main thread's.
  @Test func anEventInsideASubagentNamesIt() throws {
    let claude = AgentHookCatalogue.claude
    func change(_ json: String) -> SubagentReport? {
      let payload = AgentHookPayload(json: Data(json.utf8))!
      return claude.event(for: payload)?.subagentChange(for: payload)
    }
    #expect(
      change(#"{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"Explore"}"#)
        == SubagentReport(id: "a1", type: "Explore", phase: .started))
    #expect(
      change(#"{"hook_event_name":"SubagentStop","agent_id":"a1","agent_type":"Explore"}"#)
        == SubagentReport(id: "a1", type: "Explore", phase: .ended))
    #expect(
      change(
        #"{"hook_event_name":"PreToolUse","agent_id":"a1","agent_type":"Explore","tool_name":"Grep"}"#
      ) == SubagentReport(id: "a1", type: "Explore", phase: .working))
    #expect(
      change(#"{"hook_event_name":"UserPromptSubmit","agent_id":"a1"}"#)
        == SubagentReport(id: "a1", phase: .working),
      "any event of a worker's keeps it on the roster")
    let insideWorker = AgentHookPayload(
      json: Data(#"{"hook_event_name":"UserPromptSubmit","agent_id":"a1"}"#.utf8))!
    #expect(
      claude.event(for: insideWorker)?.startsTurn(for: insideWorker) == false,
      "a prompt inside a worker starts no turn of the agent's")
    let ownPrompt = AgentHookPayload(json: Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))!
    #expect(claude.event(for: ownPrompt)?.startsTurn(for: ownPrompt) == true)
    #expect(change(#"{"hook_event_name":"PreToolUse","tool_name":"Grep"}"#) == nil)
    #expect(
      change(#"{"hook_event_name":"Stop","agent_type":"reviewer"}"#) == nil,
      "a session run under --agent names a type and no worker")
  }
  /// Read as the agent's own, an unnamed start would leave a worker on the roster for the
  /// rest of the turn, and the Done its Stop owes unpaid.
  @Test func aSubagentEventThatNamesNoWorkerTakesAnUnnamedPlace() {
    for integration in [
      AgentHookCatalogue.claude, AgentHookCatalogue.codex, AgentHookCatalogue.copilot,
    ] {
      func change(_ event: String) -> SubagentReport? {
        let payload = AgentHookPayload(json: Data(#"{"hook_event_name":"\#(event)"}"#.utf8))!
        return integration.event(for: payload)?.subagentChange(for: payload)
      }
      let anonymous = SubagentReport.anonymousID
      if integration.id != AgentHookCatalogue.copilot.id {
        #expect(
          change("SubagentStart") == SubagentReport(id: anonymous, phase: .started),
          "\(integration.id) starts")
      }
      #expect(
        change("SubagentStop") == SubagentReport(id: anonymous, phase: .ended),
        "\(integration.id) stops")
    }
    // Any other event is the agent's own unless it names a worker, so an
    // unnamed tool call still puts no phantom on the roster.
    let call = AgentHookPayload(json: Data(#"{"hook_event_name":"PreToolUse"}"#.utf8))!
    #expect(AgentHookCatalogue.claude.event(for: call)?.subagentChange(for: call) == nil)
  }
}
