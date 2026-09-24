import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A worker's id across the helper link, in both directions.
extension AgentHooksTests {
  /// The field a worker rides on, both directions: an older helper and an older
  /// app each have to meet a newer one over the shared helper link.
  @Test func aSubagentSurvivesTheWireBothWays() throws {
    let worker = SubagentReport(id: "agent_1", type: "Explore", phase: .working)
    let sent = SessionStateReport(state: .running, agent: "claude", subagent: worker)
    let line = try sent.encodedLine()
    #expect(line.contains(#""subagent":{"id":"agent_1","phase":"working","type":"Explore"}"#))
    #expect(try #require(SessionStateReport.parse(line)) == sent)
    #expect(SessionStateReport.parse(line)?.subagentChange == worker)

    let quiet = try SessionStateReport(state: .done).encodedLine()
    #expect(!quiet.contains("subagent"), "a report that is not about them says nothing")
    #expect(SessionStateReport.parse(quiet)?.subagentChange == nil)

    // What an older helper writes: a count, read as an unnamed worker.
    let old = #"{"v":1,"state":"done","agent":"claude"}"#
    #expect(SessionStateReport.parse(old)?.subagentChange == nil, "absent reads as no change")
    let counted = #"{"v":1,"state":"running","subagents":1,"somethingLater":true}"#
    #expect(
      SessionStateReport.parse(counted)?.subagentChange
        == SubagentReport(id: SubagentReport.anonymousID, phase: .started))
    let uncounted = #"{"v":1,"state":"running","subagents":-1}"#
    #expect(
      SessionStateReport.parse(uncounted)?.subagentChange
        == SubagentReport(id: SubagentReport.anonymousID, phase: .ended))
  }

  /// The other direction: a newer helper writing to an older app, which reads
  /// the count and ignores the object. A tool call carries no count.
  @Test func aNewHelpersWorkerIsCountedForAnOlderApp() throws {
    func line(_ phase: SubagentReport.Phase) throws -> String {
      try SessionStateReport(
        state: .running, subagent: SubagentReport(id: "agent_1", type: "Explore", phase: phase)
      ).encodedLine()
    }
    #expect(try line(.started).contains(#""subagents":1"#))
    #expect(try line(.ended).contains(#""subagents":-1"#))
    #expect(try !line(.working).contains(#""subagents""#))

    let start = try line(.started)
    #expect(
      SessionStateReport.parse(start)?.subagentChange
        == SubagentReport(id: "agent_1", type: "Explore", phase: .started),
      "a new app still reads the named worker, not the count")
  }

  /// Claude names the subagent on every event of its own, so each says which
  /// worker it is about; an event naming none is the main thread's.
  @Test func anEventInsideASubagentNamesIt() throws {
    let claude = AgentHooks.claude
    func change(_ json: String) -> SubagentReport? {
      let payload = AgentHookPayload(json: Data(json.utf8))!
      return claude.event(for: payload)?.subagentReport(for: payload)
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
    for integration in [AgentHooks.claude, AgentHooks.codex, AgentHooks.copilot] {
      func change(_ event: String) -> SubagentReport? {
        let payload = AgentHookPayload(json: Data(#"{"hook_event_name":"\#(event)"}"#.utf8))!
        return integration.event(for: payload)?.subagentReport(for: payload)
      }
      let anonymous = SubagentReport.anonymousID
      if integration.id != AgentHooks.copilot.id {
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
    #expect(AgentHooks.claude.event(for: call)?.subagentReport(for: call) == nil)
  }
}
