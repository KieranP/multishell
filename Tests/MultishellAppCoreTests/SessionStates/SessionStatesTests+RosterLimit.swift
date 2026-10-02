import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
  private var capacity: Int { SessionStateReport.rosterCapacity }

  @Test func aRosterWithNoEndsStopsGrowingAtItsLimitAndStillCountsEveryWorker() {
    var states = SessionStates()
    for index in 0..<capacity + 10 { _ = report(&states, .running, started("w\(index)")) }

    #expect(workersOut(states).count == capacity + 1, "the overflow place stands for the rest")
    #expect(workersOut(states).first == "w0")
    #expect(states.workers(.session(a)).workerCount == capacity + 10)
  }

  @Test func aDoneWaitsForEveryWorkerStartedPastTheRosterLimit() {
    var states = SessionStates()
    for index in 0..<capacity + 6 { _ = report(&states, .running, started("w\(index)")) }
    #expect(report(&states, .done) == .running)

    for index in (1..<capacity + 6).reversed() { _ = report(&states, .running, ended("w\(index)")) }
    #expect(states[.session(a)] == .running, "the oldest is still out")

    #expect(report(&states, .running, ended("w0")) == .done)
    #expect(workersOut(states).isEmpty)
  }

  @Test func aWorkerPastTheRosterLimitIsCountedOnceHoweverManyToolCallsItMakes() {
    var states = SessionStates()
    for index in 0..<capacity + 6 { _ = report(&states, .running, started("w\(index)")) }
    for _ in 0..<5 { _ = report(&states, .running, working("w\(capacity + 5)")) }
    #expect(states.workers(.session(a)).workerCount == capacity + 6)

    _ = report(&states, .done)
    for index in 0..<capacity + 6 { _ = report(&states, .running, ended("w\(index)")) }
    #expect(states[.session(a)] == .done)
    #expect(workersOut(states).isEmpty)
  }

  @Test func aStrayEndPastTheRosterLimitPaysNoWorkerStillOut() {
    var states = SessionStates()
    for index in 0..<capacity + 6 { _ = report(&states, .running, started("w\(index)")) }
    _ = report(&states, .done)

    _ = report(&states, .running, ended("never-started"))

    #expect(states.workers(.session(a)).workerCount == capacity + 6)
  }

  @Test func unnamedWorkersPastTheRosterLimitAreCountedAndEndedLikeNamedOnes() {
    var states = SessionStates()
    for index in 0..<capacity { _ = report(&states, .running, started("w\(index)")) }
    let unnamed = WorkerReport.anonymousID
    for _ in 0..<2 { _ = report(&states, .running, WorkerReport(id: unnamed, phase: .started)) }
    _ = report(&states, .running, WorkerReport(id: unnamed, phase: .working))
    #expect(states.workers(.session(a)).workerCount == capacity + 2)

    for _ in 0..<2 { _ = report(&states, .running, ended(unnamed)) }
    #expect(workersOut(states) == (0..<capacity).map { "w\($0)" })
  }
}
