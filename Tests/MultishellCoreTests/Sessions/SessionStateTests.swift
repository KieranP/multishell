import Foundation
import Testing

@testable import MultishellCore

struct SessionStateTests {
  @Test func theMostUrgentStateWinsAndIdleIsNothing() {
    #expect(SessionState.mostUrgent([.done, .attention, .running]) == .attention)
    #expect(SessionState.mostUrgent([.done, .running]) == .running)
    #expect(SessionState.mostUrgent([.running, .failed]) == .failed, "a failure outranks work")
    #expect(
      SessionState.mostUrgent([.attention, .failed]) == .failed,
      "and a question: a row with a failed tab is red whatever the others ask")
    #expect(SessionState.mostUrgent([.idle, .done]) == .done, "one finished tab is enough")
    #expect(SessionState.mostUrgent([.idle, .idle]) == nil, "idle only when every tab is")
    #expect(SessionState.mostUrgent([.idle]) == nil)
    #expect(SessionState.mostUrgent([]) == nil)
    #expect(SessionState.idle.nonIdle == nil)
    #expect(SessionState.done.nonIdle == .done)
  }

  @Test func aFailureTravelsAndIsSavedAsError() {
    #expect(SessionState.failed.rawValue == "error")
    #expect(SessionState(rawValue: "error") == .failed)
  }

  @Test func exitCodesBecomeDoneOrFailedAndSignalsAreNotFailures() {
    #expect(SessionState.finished(exitCode: 0) == .done)
    #expect(SessionState.finished(exitCode: nil) == .done)
    #expect(SessionState.finished(exitCode: 1) == .failed)
    #expect(SessionState.finished(exitCode: 127) == .failed)
    #expect(SessionState.finished(exitCode: 130) == .done, "Ctrl+C is the user's own doing")
    #expect(SessionState.failed.isFinished && SessionState.done.isFinished)
    #expect(!SessionState.running.isFinished)
  }
}
