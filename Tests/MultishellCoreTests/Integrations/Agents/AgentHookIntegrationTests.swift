import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentHookIntegrationTests: AgentHookFixtures {
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
