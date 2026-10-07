import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentHookEventTests {
  /// Claude names the subagent on every event of its own, so each says which
  /// worker it is about; an event naming none is the main thread's.
  @Test func anEventInsideASubagentNamesIt() throws {
    let claude = AgentHookCatalogue.claude
    func change(_ json: String) throws -> WorkerReport? {
      let payload = try #require(AgentHookPayload(json: Data(json.utf8)))
      return claude.event(for: payload)?.workerChange(for: payload)
    }
    #expect(
      try change(#"{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"Explore"}"#)
        == WorkerReport(id: "a1", type: "Explore", phase: .started))
    #expect(
      try change(#"{"hook_event_name":"SubagentStop","agent_id":"a1","agent_type":"Explore"}"#)
        == WorkerReport(id: "a1", type: "Explore", phase: .ended))
    #expect(
      try change(
        #"{"hook_event_name":"PreToolUse","agent_id":"a1","agent_type":"Explore","tool_name":"Grep"}"#
      ) == WorkerReport(id: "a1", type: "Explore", phase: .working))
    #expect(
      try change(#"{"hook_event_name":"UserPromptSubmit","agent_id":"a1"}"#)
        == WorkerReport(id: "a1", phase: .working),
      "any event of a worker's keeps it on the roster")
    #expect(try change(#"{"hook_event_name":"PreToolUse","tool_name":"Grep"}"#) == nil)
    #expect(
      try change(#"{"hook_event_name":"Stop","agent_type":"reviewer"}"#) == nil,
      "a session run under --agent names a type and no worker")
  }

  @Test func onlyTheAgentsOwnPromptStartsATurn() throws {
    let claude = AgentHookCatalogue.claude
    let insideWorker = try #require(
      AgentHookPayload(json: Data(#"{"hook_event_name":"UserPromptSubmit","agent_id":"a1"}"#.utf8)))
    #expect(claude.event(for: insideWorker)?.startsTurn(for: insideWorker) == false)
    let ownPrompt = try #require(
      AgentHookPayload(json: Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8)))
    #expect(claude.event(for: ownPrompt)?.startsTurn(for: ownPrompt) == true)
  }

  /// Read as the agent's own, an unnamed start would leave a worker on the roster for the
  /// rest of the turn, and the Done its Stop owes unpaid.
  @Test func aSubagentEventThatNamesNoWorkerTakesAnUnnamedPlace() {
    for integration in [
      AgentHookCatalogue.claude, AgentHookCatalogue.codex, AgentHookCatalogue.copilot,
    ] {
      func change(_ event: String) -> WorkerReport? {
        let payload = AgentHookPayload(eventName: event)
        return integration.event(for: payload)?.workerChange(for: payload)
      }
      let anonymous = WorkerReport.anonymousID
      if integration.id != AgentHookCatalogue.copilot.id {
        #expect(
          change("SubagentStart") == WorkerReport(id: anonymous, phase: .started),
          "\(integration.id) starts")
      }
      #expect(
        change("SubagentStop") == WorkerReport(id: anonymous, phase: .ended),
        "\(integration.id) stops")
    }
    // Any other event is the agent's own unless it names a worker, so an
    // unnamed tool call still puts no phantom on the roster.
    let call = AgentHookPayload(eventName: "PreToolUse")
    #expect(AgentHookCatalogue.claude.event(for: call)?.workerChange(for: call) == nil)
  }
}
