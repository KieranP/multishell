import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension AppModelSessionReportsTests {
  @Test func aSessionStartAfterThePromptLeavesThePaneWorking() {
    let pane = CopilotPaneHarness()
    pane.hook(CopilotPayload.prompt)
    pane.hook(CopilotPayload.sessionStart)

    #expect(pane.state == .running)
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)
  }

  @Test func aDroppedSessionStartOfAnotherConversationLeavesThePanesOwn() {
    let pane = CopilotPaneHarness()
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
    let pane = CopilotPaneHarness()
    pane.hook(CopilotPayload.prompt)
    pane.hook(CopilotPayload.stop)
    pane.hook(CopilotPayload.sessionStart)

    #expect(pane.state == nil)
  }

  @Test func aSubagentsOwnStopIsNotThePanesDone() {
    let pane = CopilotPaneHarness()
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
    let pane = CopilotPaneHarness()
    pane.hook(CopilotPayload.childTool)
    pane.hook(CopilotPayload.childStop)
    pane.hook(CopilotPayload.subagentStop)
    pane.hook(CopilotPayload.taskDone)

    #expect(pane.workers.isEmpty, "the parent is the pane's own, not a worker")
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)
  }

  @Test func aSubagentOutlivingTheTurnHoldsTheDoneUntilTheTurnItsEndWakes() {
    let pane = CopilotPaneHarness()
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
    #expect(pane.state == .running, "its end wakes the parent")
    pane.hook(CopilotPayload.stop)
    #expect(pane.state == .done)
  }

  @Test func aNewConversationWithNoSessionStartIsThePanesOwnByItsStop() {
    let pane = CopilotPaneHarness()
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
