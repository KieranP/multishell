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

  @Test func aToolCallNamingTheParentAfterTheStartPutsTheWorkerUnderIt() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", type: "general-purpose", phase: .started))
    roster.record(WorkerReport(id: "a1", type: "general-purpose", phase: .started))
    roster.record(
      WorkerReport(
        id: "a1", type: "general-purpose", phase: .working, parentID: "a0",
        name: "Efficiency angle"))
    roster.record(WorkerReport(id: "a1", type: "general-purpose", phase: .working))

    let worker = roster.workers.last
    #expect(worker?.parentID == "a0", "a report that does not say leaves it")
    #expect(worker?.displayName == "Efficiency angle")
    #expect(worker?.occurrences == 1)
  }

  @Test func aWorkerFirstHeardAtAToolCallArrivesUnderItsParent() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a1", phase: .working, parentID: "a0", name: "Reuse angle"))
    #expect(roster.workers.map(\.parentID) == ["a0"])
    #expect(roster.workers.map(\.displayName) == ["Reuse angle"])
  }
}
