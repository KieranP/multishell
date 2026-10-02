import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct WorkerRosterTests {
  @Test func aWorkerForgottenPastTheRosterLimitTakesEveryStartUnderItsId() {
    let capacity = SessionStateReport.rosterCapacity
    var roster = WorkerRoster()
    for index in 0..<capacity {
      _ = roster.record(WorkerReport(id: "w\(index)", type: "Explore", phase: .started))
    }
    _ = roster.record(WorkerReport(id: "conversation", type: "Explore", phase: .started))
    _ = roster.record(WorkerReport(id: "conversation", type: "Explore", phase: .started))

    roster.forget("conversation")

    #expect(roster.workers.workerCount == capacity)
    #expect(roster.overflowed.isEmpty)
  }
}
