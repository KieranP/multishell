import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Copilot 1.0.87's own payloads, captured from `copilot -p` spawning one
/// subagent, driven through the report the helper builds and into the model.
private enum CopilotPayload {
  static let copilot = AgentHookCatalogue.integration("copilot")!
  static let parent = "17954dff-e162-4e7a-925e-a59ca530c5fb"
  static let child = "37880ecf-c5f3-42ce-afe0-82b221d75839"
  static let transcript = "/Users/dev/.copilot/session-state/\(parent)/events.jsonl"

  static let sessionStart =
    #"{"hook_event_name":"SessionStart","session_id":"\#(parent)","cwd":"/w","source":"new"}"#
  static let prompt =
    #"{"hook_event_name":"UserPromptSubmit","session_id":"\#(parent)","cwd":"/w","prompt":"go"}"#
  static let taskCall =
    #"{"hook_event_name":"PreToolUse","session_id":"\#(parent)","cwd":"/w","tool_name":"Agent"}"#
  static let subagentStart =
    #"{"sessionId":"\#(parent)","cwd":"/w","transcriptPath":"\#(transcript)","agentName":"general-purpose"}"#
  static let childPrompt =
    #"{"hook_event_name":"UserPromptSubmit","session_id":"\#(child)","cwd":"/w","prompt":"sub"}"#
  static let childTool =
    #"{"hook_event_name":"PreToolUse","session_id":"\#(child)","cwd":"/w","tool_name":"Bash"}"#
  static let childStop =
    #"{"hook_event_name":"Stop","session_id":"\#(child)","cwd":"/w","transcript_path":"\#(transcript)","stop_reason":"end_turn"}"#
  static let subagentStop =
    #"{"hook_event_name":"SubagentStop","session_id":"\#(parent)","cwd":"/w","transcript_path":"\#(transcript)","agent_id":"\#(child)","agent_type":"general-purpose","agent_name":"general-purpose","stop_reason":"end_turn"}"#
  static let taskDone =
    #"{"hook_event_name":"PostToolUse","session_id":"\#(parent)","cwd":"/w","tool_name":"Agent"}"#
  static let stop =
    #"{"hook_event_name":"Stop","session_id":"\#(parent)","cwd":"/w","transcript_path":"\#(transcript)","stop_reason":"end_turn"}"#
}

@MainActor private struct CopilotPane {
  let h = Harness()
  let tab: TerminalTab
  var session: TerminalSession.ID { tab.focusedSessionID }

  init() {
    h.model.select(h.main)
    tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
  }

  @discardableResult
  func hook(_ json: String) -> SessionStateReport? {
    guard let payload = AgentHookPayload(json: Data(json.utf8)),
      let report = CopilotPayload.copilot.report(
        for: payload, sessionID: session, cwd: nil, pid: nil)
    else { return nil }
    h.source.send(report)
    return report
  }

  var state: SessionState? { h.model.state(of: tab) }
  var workers: [String] { h.model.sessionStates.subagents(.session(session)).map(\.id) }
}

extension AppModelSessionReportsTests {
  @Test func aSessionStartAfterThePromptLeavesThePaneWorking() {
    let pane = CopilotPane()
    pane.hook(CopilotPayload.prompt)
    pane.hook(CopilotPayload.sessionStart)

    #expect(pane.state == .running)
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)
  }

  @Test func aDroppedSessionStartOfAnotherConversationLeavesThePanesOwn() {
    let pane = CopilotPane()
    pane.hook(CopilotPayload.sessionStart)
    pane.hook(CopilotPayload.prompt)
    pane.hook(
      #"{"hook_event_name":"SessionStart","session_id":"\#(CopilotPayload.child)","cwd":"/w","source":"new"}"#
    )

    pane.hook(CopilotPayload.taskCall)

    #expect(pane.workers.isEmpty)
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)
  }

  @Test func aSessionStartOverAFinishedTurnStillClearsIt() {
    let pane = CopilotPane()
    pane.hook(CopilotPayload.prompt)
    pane.hook(CopilotPayload.stop)
    pane.hook(CopilotPayload.sessionStart)

    #expect(pane.state == nil)
  }

  @Test func aSubagentsOwnStopIsNotThePanesDone() {
    let pane = CopilotPane()
    for json in [
      CopilotPayload.sessionStart, CopilotPayload.prompt, CopilotPayload.taskCall,
      CopilotPayload.subagentStart,
    ] {
      pane.hook(json)
    }
    pane.hook(CopilotPayload.childPrompt)
    pane.hook(CopilotPayload.childTool)
    #expect(pane.state == .running)
    #expect(pane.workers == [CopilotPayload.child], "the child's own session is the worker")

    #expect(pane.hook(CopilotPayload.childStop) == nil, "the child's Stop sends nothing")
    #expect(pane.state == .running)
    pane.hook(CopilotPayload.subagentStop)
    #expect(pane.workers.isEmpty, "its end names it by the same id")
    pane.hook(CopilotPayload.taskDone)
    #expect(pane.state == .running)

    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)
  }

  @Test func aPaneFirstHearingASubagentCountsTheParentOnceItsEndNamesIt() {
    let pane = CopilotPane()
    pane.hook(CopilotPayload.childTool)
    pane.hook(CopilotPayload.childStop)
    pane.hook(CopilotPayload.subagentStop)
    pane.hook(CopilotPayload.taskDone)

    #expect(pane.workers.isEmpty, "the parent is the pane's own, not a worker")
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)
  }

  @Test func aSubagentOutlivingTheTurnHoldsTheDoneUntilItEnds() {
    let pane = CopilotPane()
    for json in [
      CopilotPayload.sessionStart, CopilotPayload.prompt, CopilotPayload.taskCall,
      CopilotPayload.childPrompt,
    ] {
      pane.hook(json)
    }
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .running, "a worker is still out")
    pane.hook(CopilotPayload.childTool)
    pane.hook(CopilotPayload.childStop)
    #expect(pane.state == .running)
    pane.hook(CopilotPayload.subagentStop)
    #expect(pane.state == .done, "the last one out pays it")
  }

  @Test func aNewConversationWithNoSessionStartIsThePanesOwnByItsStop() {
    let pane = CopilotPane()
    pane.hook(CopilotPayload.prompt)
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)

    let next = "8a5fd23a-a0c8-44a1-9425-4344e24a7d81"
    let nextTranscript = "/Users/dev/.copilot/session-state/\(next)/events.jsonl"
    pane.hook(
      #"{"hook_event_name":"UserPromptSubmit","session_id":"\#(next)","cwd":"/w","prompt":"again"}"#
    )
    #expect(pane.state == .running)
    pane.hook(
      #"{"hook_event_name":"Stop","session_id":"\#(next)","cwd":"/w","transcript_path":"\#(nextTranscript)"}"#
    )
    #expect(pane.workers.isEmpty)
    #expect(pane.state == .done)
  }
}
